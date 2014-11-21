//
//  RCCDeviceRequest.m
//  RetainCC
//
//  Created by b123400 on 17/11/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import "RCCDeviceRequest.h"

@implementation RCCDeviceRequest

- (void)send:(void (^)(BOOL, NSError *))callback{
    
    NSMutableDictionary *params = @{}.mutableCopy;
    
    if (self.userID) {
        [params setObject:self.userID forKey:@"user_id"];
    }
    if (self.email) {
        [params setObject:self.email forKey:@"email"];
    }
    if (self.uid) {
        [params setObject:self.uid forKey:@"uid"];
    }
    
    if (self.pushToken) {
        [params setObject:self.pushToken forKey:@"push_token"];
    }
    
    NSMutableURLRequest *request = [self authedRequestWithJSON:params];
    [request setURL:[NSURL URLWithString:@"https://app.retain.cc/api/v1/devices"]];
    [self sendRequest:request callback:callback];
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    
    self.pushToken = [aDecoder decodeObjectForKey:@"pushToken"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.pushToken forKey:@"pushToken"];
}

@end
