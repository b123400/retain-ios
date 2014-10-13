//
//  RCCUserAttributeRequest.m
//  retaincc
//
//  Created by b123400 on 3/10/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import "RCCUserAttributeRequest.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface RCCUserAttributeRequest ()

+ (NSString *)getIPAddress;

@end


@implementation RCCUserAttributeRequest

- (void)send:(void (^)(BOOL, NSError *))callback{
    
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
    
    
    for (NSString *key in self.attributes) {
        if ([apiFields containsObject:key]) {
            [params setObject:[self.attributes objectForKey:key] forKey:key];
        } else {
            // put it into custom data
            [customData setObject:[self.attributes objectForKey:key] forKey:key];
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
    
    NSString *ipAddress = [RCCUserAttributeRequest getIPAddress];
    if (![ipAddress isEqualToString:@"error"]) {
        [params setObject:ipAddress forKey:@"last_seen_ip"];
    }
    
    NSMutableURLRequest *request = [self authedRequestWithJSON:params];
    [request setURL:[NSURL URLWithString:@"https://app.retain.cc/api/v1/users"]];
    [self sendRequest:request callback:callback];
}

+ (NSString *)getIPAddress {
    
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

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    
    self.attributes = [aDecoder decodeObjectForKey:@"attributes"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:self.attributes forKey:@"attributes"];
}

@end
