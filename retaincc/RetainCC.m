//
//  RetainCC.m
//  retaincc
//
//  Created by b123400 on 22/9/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import "RetainCC.h"
#import "RCCEventRequest.h"
#import "RCCUserAttributeRequest.h"
#import "RCCImpressionRequest.h"
#import "RCCDeviceRequest.h"
#import "Reachability.h"

// 10 minutes
#define kRetainCCPingInterval 600

#if !defined(DEBUG) && !defined (RETAINCC_VERBOSE)
#define NSLog(...)
#endif

@interface NSData (Conversion)
- (NSString *)hexadecimalString;
@end

@interface RetainCC ()

@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *appID;

@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *pushToken;

@property (nonatomic, strong) NSTimer *retryTimer;
@property (nonatomic, strong) NSTimer *periodicPingTimer;

- (void)setUid:(NSString*)uid;

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict callback:(void(^)(BOOL success, NSError *error))callback;
- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID callback:(void(^)(BOOL success, NSError *error))callback;
- (void)changeUserAttributes:(NSDictionary*)dictionary callback:(void(^)(BOOL success, NSError *error))callback;
- (void)sendDeviceRequest:(void(^)(BOOL success, NSError *error))callback;
- (void)sendPeriodicRequest;

#pragma mark Saving
- (void)saveUserInfo;
- (void)addPendingRequest:(RCCRequest*)request;
- (void)executePendingRequests;

- (void)scheduleRetryTimer;
- (void)retryTimerCalled:(NSTimer*)timer;

- (void)reachabilityChanged:(NSNotification*)notification;
- (NSString *)filePathForData:(NSString *)data;

@end

@implementation RetainCC
static RetainCC *sharedInstance = nil;

+ (instancetype)sharedInstanceWithApiKey:(NSString*)apiKey appID:(NSString*)appID{
    if (sharedInstance) {
        // warn for calling twice?
    } else {
        sharedInstance = [[RetainCC alloc] initWithApiKey:apiKey appID:appID];
        [sharedInstance restoreUserInfo];
        [sharedInstance executePendingRequests];
    }
    return sharedInstance;
}
+ (instancetype)shared{
    if (!sharedInstance) {
        NSLog(@"You have to call sharedInstanceWithApiKey:appID: before calling sharedInstance");
    }
    return sharedInstance;
}

- (instancetype)initWithApiKey:(NSString*)apiKey appID:(NSString*)appID{
    self = [super init];
    
    self.apiKey = apiKey;
    self.appID = appID;
    
    Reachability *reach = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    [reach startNotifier];
    
    self.periodicPingTimer = [NSTimer scheduledTimerWithTimeInterval:kRetainCCPingInterval target:self selector:@selector(periodicPingTimerCalled:) userInfo:nil repeats:YES];
    [self sendPeriodicRequest];
    
    return self;
}

- (void)setUid:(NSString *)uid{
    if ([uid isEqualToString:_uid]) {
        return;
    }
    _uid = uid;
    [self saveUserInfo];
}

#pragma mark - public methods

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict {
    [self logEventWithName:name properties:dict callback:nil];
}

- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID {
    [self identifyWithEmail:email userID:userID callback:nil];
}
- (void)changeUserAttributes:(NSDictionary*)dictionary {
    [self changeUserAttributes:dictionary callback:nil];
}

- (void)setDevicePushToken:(NSData *)pushToken{
    NSString *tokenString = [pushToken hexadecimalString];
    if ([tokenString isEqualToString:self.pushToken]) {
        return;
    }
    self.pushToken = tokenString;
    [self saveUserInfo];
    [self sendDeviceRequest:^(BOOL success, NSError *error) {
        
    }];
}

#pragma mark - private methods

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict callback:(void(^)(BOOL success, NSError *error))callback {
    
    RCCEventRequest *eventRequest = [[RCCEventRequest alloc] initWithApiKey:self.apiKey appID:self.appID];
    eventRequest.name = name;
    eventRequest.properties = dict;
    eventRequest.userID = self.userID;
    eventRequest.email = self.email;
    eventRequest.uid = self.uid;
    
    [eventRequest send:^(BOOL success, NSError *error) {
        if (!success) {
            [self addPendingRequest:eventRequest];
        }
        if (callback) {
            callback(success, error);
        }
    }];
}

- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID callback:(void(^)(BOOL success, NSError *error))callback {
    if (![email isEqualToString:self.email] || ![userID isEqualToString:self.userID]) {
        // user changed so uid is not valid anymore
        self.uid = nil;
    }
    self.userID = userID;
    self.email = email;

    [self saveUserInfo];
    [self sendPeriodicRequest:callback];
    [self sendDeviceRequest:^(BOOL success, NSError *error) {
        
    }];
}

- (void)changeUserAttributes:(NSDictionary*)dictionary callback:(void(^)(BOOL success, NSError *error))callback {
    RCCUserAttributeRequest *userRequest = [[RCCUserAttributeRequest alloc] initWithApiKey:self.apiKey appID:self.appID];
    userRequest.userID = self.userID;
    userRequest.email = self.email;
    userRequest.uid = self.uid;
    userRequest.attributes = dictionary;
    
    [userRequest send:^(BOOL success, NSError *error) {
        if (!success) {
            [self addPendingRequest:userRequest];
        }
        if (callback) {
            callback(success, error);
        }
    }];
}

- (void)sendDeviceRequest:(void(^)(BOOL success, NSError *error))callback {
    RCCDeviceRequest *request = [[RCCDeviceRequest alloc] initWithApiKey:self.apiKey appID:self.appID];
    request.userID = self.userID;
    request.email = self.email;
    request.uid = self.uid;
    request.pushToken = self.pushToken;
    [request send:callback];
}

# pragma - saving things

- (void)saveUserInfo {
    NSString *filename = [self filePathForData:@"user"];
    NSMutableDictionary *userInfo = @{}.mutableCopy;
    if (self.userID) {
        [userInfo setObject:self.userID forKey:@"userID"];
    }
    if (self.email) {
        [userInfo setObject:self.email forKey:@"email"];
    }
    if (self.uid) {
        [userInfo setObject:self.uid forKey:@"uid"];
    }
    if (self.pushToken) {
        [userInfo setObject:self.pushToken forKey:@"pushToken"];
    }
    [userInfo writeToFile:filename atomically:YES];
}

- (void)restoreUserInfo {
    NSString *filename = [self filePathForData:@"user"];
    NSDictionary *userInfo = [NSDictionary dictionaryWithContentsOfFile:filename];
    if ([userInfo objectForKey:@"userID"]) {
        self.userID = [userInfo objectForKey:@"userID"];
    }
    if ([userInfo objectForKey:@"email"]) {
        self.email = [userInfo objectForKey:@"email"];
    }
    if ([userInfo objectForKey:@"uid"]) {
        self.uid = [userInfo objectForKey:@"uid"];
    }
    if ([userInfo objectForKey:@"pushToken"]) {
        self.pushToken = [userInfo objectForKey:@"pushToken"];
    }
}

# pragma Error handling and retry

- (void)request:(RCCRequest*)request failedWithError:(NSError*)error{
    NSUInteger errorCode = error.code;
    
    if (errorCode == 0) {
        // offline
        [self addPendingRequest:request];
        // will retry when network status changed
    }
    if (errorCode >= 500) {
        // server error, let's retry later
        [self addPendingRequest:request];
        [self scheduleRetryTimer];
    }
    if (errorCode >= 400) {
        // client error, such as wrong api key, give up and report
        NSLog(@"RetainCC Error: %@", error.localizedDescription);
    }
}

- (void)addPendingRequest:(RCCRequest*)request {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.oursky.saving", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(queue, ^{
        NSString *requestQueueFilename = [self filePathForData:@"requests"];
        NSMutableArray *savedRequest = [NSMutableArray arrayWithContentsOfFile:requestQueueFilename];
        if (!savedRequest) {
            savedRequest = @[].mutableCopy;
        }
        [savedRequest addObject:request];
        [NSKeyedArchiver archiveRootObject:savedRequest toFile:requestQueueFilename];
    });
}

- (void)executePendingRequests {
    NSString *requestPath = [self filePathForData:@"requests"];
    NSMutableArray *requests = [NSKeyedUnarchiver unarchiveObjectWithFile:requestPath];
    if (!requests) {
        return;
    }
    [NSKeyedArchiver archiveRootObject:@[] toFile:requestPath];
    for (RCCRequest *request in requests) {
        [request send:^(BOOL success, NSError *error) {
            if (!success) {
                [self addPendingRequest:request];
            }
        }];
    }
}

- (void)scheduleRetryTimer {
    if (self.retryTimer) return; // already scheduled
    self.retryTimer = [NSTimer scheduledTimerWithTimeInterval:5*60 target:self selector:@selector(retryTimerCalled:) userInfo:nil repeats:NO];
}

- (void)retryTimerCalled:(NSTimer*)timer {
    [timer invalidate];
    self.retryTimer = nil;
    [self executePendingRequests];
}

#pragma mark Periodic ping

- (void)sendPeriodicRequest:(void(^)(BOOL success, NSError *error))callback {
    RCCImpressionRequest *request = [[RCCImpressionRequest alloc] initWithApiKey:self.apiKey appID:self.appID];
    request.userID = self.userID;
    request.email = self.email;
    request.uid = self.uid;
    [request send:callback];
}

- (void)sendPeriodicRequest {
    [self sendPeriodicRequest:nil];
}

- (void)periodicPingTimerCalled:(NSTimer*)timer {
    [self sendPeriodicRequest];
}

#pragma mark Utility

- (NSString *)filePathForData:(NSString *)data{
    NSString *filename = [NSString stringWithFormat:@"RetainCC-%@-%@.plist", self.apiKey, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

#pragma mark Notification

- (void)reachabilityChanged:(NSNotification*)notification {
    [self executePendingRequests];
}

@end

#pragma mark Utility

@implementation NSData (Conversion)
- (NSString *)hexadecimalString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02lx", (unsigned long)dataBuffer[i]];
    }
    
    return hexString;
}
@end