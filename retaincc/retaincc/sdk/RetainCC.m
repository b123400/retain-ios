//
//  RetainCC.m
//  retaincc
//
//  Created by b123400 on 22/9/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import "RetainCC.h"
#import <AFNetworking/AFNetworking.h>
#include <ifaddrs.h>
#include <arpa/inet.h>


@interface RetainCC ()

@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *appID;

@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *email;

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict callback:(void(^)(BOOL success, NSError *error))callback;
- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID callback:(void(^)(BOOL success, NSError *error))callback;
- (void)changeUserAttributes:(NSDictionary*)dictionary callback:(void(^)(BOOL success, NSError *error))callback;

# pragma mark Utility

- (AFHTTPRequestOperationManager*)prepareManager;
- (NSString *)getIPAddress;

#pragma mark Saving
- (void)saveUserInfo;
- (void)addPendingRequestInfo:(NSDictionary*)information;
- (NSString *)filePathForData:(NSString *)data;

@end

@implementation RetainCC
static RetainCC *sharedInstance = nil;

+ (instancetype)sharedInstanceWithApiKey:(NSString*)apiKey appID:(NSString*)appID{
    if (sharedInstance) {
        // warn for calling twice?
    } else {
        sharedInstance = [[RetainCC alloc] initWithApiKey:apiKey appID:appID];
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
    
    [self restoreUserInfo];
    
    return self;
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

#pragma mark - private methods

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict callback:(void(^)(BOOL success, NSError *error))callback {
    
    AFHTTPRequestOperationManager *manager = [self prepareManager];
    [manager.responseSerializer setAcceptableContentTypes: [NSSet setWithObject:@"text/plain"]];
    
    NSMutableDictionary *params = @{}.mutableCopy;
    [params setObject:name forKey:@"event"];
    if (self.userID) {
        [params setObject:self.userID forKey:@"user_id"];
    } else if (self.email) {
        [params setObject:self.email forKey:@"email"];
    }
    if (dict) {
        [params setObject:dict forKey:@"custom_data"];
    }
    
    [manager POST:@"https://app.retain.cc/api/v1/events" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"operation success: %@", operation);
        NSLog(@"response: %@", [responseObject description]);
        if (callback) {
            callback( YES, nil );
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"operation failed: %@", operation.description);
        NSLog(@"error: %@", error.localizedDescription);
        if (callback) {
            callback( NO, error );
        }
        
        [self addPendingRequestInfo:@{
                                      @"type" : @"event",
                                      @"name" : name,
                                      @"dict" : dict
                                      }];
    }];
}

- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID callback:(void(^)(BOOL success, NSError *error))callback {
    self.userID = userID;
    self.email = email;
    [self saveUserInfo];
    if (callback) {
        callback( YES, nil );
    }
}

- (void)changeUserAttributes:(NSDictionary*)dictionary callback:(void(^)(BOOL success, NSError *error))callback {
    AFHTTPRequestOperationManager *manager = [self prepareManager];
    
    NSMutableDictionary *params = @{}.mutableCopy;
    NSMutableDictionary *customData = @{}.mutableCopy;
    
    NSArray *apiFields = @[@"user_id",
                           @"email",
                           @"name",
                           @"created_at",
                           @"custom_data",
                           @"last_seen_ip",
                           @"last_seen_user_agent",
                           @"companies",
                           @"last_impression_at",
                           @"company_id"];
    
    
    for (NSString *key in dictionary) {
        if ([apiFields containsObject:key]) {
            [params setObject:[dictionary objectForKey:key] forKey:key];
        } else {
            // put it into custom data
            [customData setObject:[dictionary objectForKey:key] forKey:key];
        }
    }
    
    [params setObject:customData forKey:@"custom_data"];
    
    if (self.userID) {
        [params setObject:self.userID forKey:@"user_id"];
    }
    if (self.email) {
        [params setObject:self.email forKey:@"email"];
    }
    [params setObject:@"iOS" forKey:@"last_seen_user_agent"];
    
    NSString *ipAddress = [self getIPAddress];
    if (![ipAddress isEqualToString:@"error"]) {
        [params setObject:ipAddress forKey:@"last_seen_ip"];
    }
    
    [manager POST:@"https://app.retain.cc/api/v1/users" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (callback) {
            callback(YES, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) {
            callback(NO, error);
        }
        
        [self addPendingRequestInfo:@{
                                      @"type" : @"userAttr",
                                      @"dict" : dictionary
                                      }];
    }];
}

# pragma mark - network utility

- (AFHTTPRequestOperationManager*)prepareManager {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager setRequestSerializer:[AFJSONRequestSerializer serializer]];
    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:self.appID password:self.apiKey];
    [manager setResponseSerializer: [AFHTTPResponseSerializer serializer]];
    
    return manager;
}

- (NSString *)getIPAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
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
}

- (void)addPendingRequestInfo:(NSDictionary*)information{
    static dispatch_once_t onceToken;
    __block dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.oursky.saving", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(queue, ^{
        NSString *requestQueueFilename = [self filePathForData:@"requests"];
        NSMutableArray *requestInfos = [NSMutableArray arrayWithContentsOfFile:requestQueueFilename];
        if (!requestQueueFilename) {
            requestInfos = @[].mutableCopy;
        }
        [requestInfos addObject:information];
        [requestInfos writeToFile:requestQueueFilename atomically:YES];
    });
}

- (void)executePendingRequestInfo {
    NSMutableArray *requestInfos = [NSMutableArray arrayWithContentsOfFile:[self filePathForData:@"requests"]];
    if (!requestInfos) {
        return;
    }
    for (NSDictionary *dict in requestInfos) {
        if ([[dict objectForKey:@"type"] isEqualToString:@"event"]) {
            NSString *name = [dict objectForKey:@"name"];
            NSDictionary *props = [dict objectForKey:@"dict"];
            [self logEventWithName:name properties:props];
            
        } else if ([[dict objectForKey:@"type"] isEqualToString:@"userAttr"]) {
            NSDictionary *attr = [dict objectForKey:@"dict"];
            [self changeUserAttributes:attr];
        }
    }
}

- (NSString *)filePathForData:(NSString *)data{
    NSString *filename = [NSString stringWithFormat:@"RetainCC-%@-%@.plist", self.apiKey, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

@end
