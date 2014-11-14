//
//  RCCImpressionRequest.m
//  RetainCC
//
//  Created by b123400 on 14/11/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import "RCCImpressionRequest.h"

@implementation RCCImpressionRequest

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
    
    [params setObject:[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]] forKey:@"last_impression_at"];
    
    NSMutableURLRequest *request = [self authedRequestWithJSON:params];
    [request setURL:[NSURL URLWithString:@"https://app.retain.cc/api/v1/users/impression"]];
    [self sendRequest:request callback:callback];
}

@end
