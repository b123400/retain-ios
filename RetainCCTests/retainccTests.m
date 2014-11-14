//
//  retainccTests.m
//  retainccTests
//
//  Created by b123400 on 22/9/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import "RetainCC.h"
#import "RCCUserAttributeRequest.h"

@interface retainccTests : XCTestCase

@end

@interface RetainCC ()

- (NSString*)userID;
- (NSString*)email;
- (NSString *)getIPAddress;

- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict callback:(void(^)(BOOL success, NSError *error))callback;
- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID callback:(void(^)(BOOL success, NSError *error))callback;
- (void)changeUserAttributes:(NSDictionary*)dictionary callback:(void(^)(BOOL success, NSError *error))callback;

@end

@interface RCCUserAttributeRequest ()
+ (NSString *)getIPAddress;
@end

@implementation retainccTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES; // Stub ALL requests without any condition
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        // Stub all those requests with "Hello World!" string
        NSData* stubData = [@"Hello World!" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:nil];
    }];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://google.com"]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssert([result isEqualToString:@"Hello World!"],@"Stub request");
}

- (void)testSendEvent {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        
        BOOL shouldApply = [request.URL.absoluteString isEqualToString:@"https://app.retain.cc/api/v1/events"];
        if (!shouldApply) return NO;
        
        NSDictionary *allHeaders = request.allHTTPHeaderFields;
        // check auth
        NSString *authString = [allHeaders objectForKey:@"Authorization"];
        XCTAssert(authString, @"No auth string found");
        authString = [authString substringFromIndex:[authString rangeOfString:@"Basic "].length];
        NSData *authData = [[NSData alloc]initWithBase64EncodedString:authString options:0];
        XCTAssert(authData, @"Auth data is not base63 encoded");
        NSString *decodedData = [[NSString alloc] initWithData:authData encoding:NSUTF8StringEncoding];
        XCTAssert([decodedData isEqualToString:@"APP_ID:API_KEY"]);
        
        // content type check
        XCTAssert([[allHeaders objectForKey:@"Content-type"] rangeOfString:@"application/json"].location != NSNotFound,@"Request Content-type should be json");
        
        XCTAssert([[request HTTPMethod] isEqualToString:@"POST"],"should use post");
        NSLog(@"%@",[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
        NSError *error = nil;
        NSDictionary *bodyData = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:kNilOptions error:&error];
        NSDictionary *shouldSend = @{
                                     @"user_id" : @"1234",
                                     @"email" : @"someone@example.com",
                                     @"event" : @"EVENT_NAME",
                                     @"custom_data" : @{
                                             @"CUSTOM_KEY" : @"CUSTOM_VALUE"
                                             }
                                     };
        NSLog(@"test send1 %@",shouldSend.description);
        NSLog(@"test send2 %@",bodyData.description);
        XCTAssert([bodyData isEqualToDictionary:shouldSend], @"body correct");
        XCTAssert(!error);
        
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        // Stub all those requests with "Hello World!" string
        NSData* stubData = [@"Hello World!" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:nil];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"send event async"];
    
    RetainCC *library = [[RetainCC alloc] initWithApiKey:@"API_KEY" appID:@"APP_ID"];
    [library identifyWithEmail:@"someone@example.com" userID:@"1234"];
    [library logEventWithName:@"EVENT_NAME" properties:@{
                                                         @"CUSTOM_KEY":@"CUSTOM_VALUE"
                                                         }
     callback:^(BOOL success, NSError *error) {
         XCTAssert(success,@"Request failed, %@", error);
         [expectation fulfill];
     }];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        NSLog(@"test error: %@", error.localizedDescription);
    }];
}

- (void)testIdentifyUser {
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"identify user"];
    
    RetainCC *library = [[RetainCC alloc] initWithApiKey:@"API_KEY" appID:@"APP_ID"];
    [library identifyWithEmail:@"test@example.com" userID:@"1234" callback:^(BOOL success, NSError *error) {
        XCTAssert([library.userID isEqualToString:@"1234"], @"user id same");
        XCTAssert([library.email isEqualToString:@"test@example.com"], @"email same");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        NSLog(@"identify error: %@", error.localizedDescription);
    }];
}

- (void)testHandlingUid {
    
    __block NSString *ipAddress = @"";
    
    RetainCC *library = [RetainCC sharedInstanceWithApiKey:@"API_KEY" appID:@"APP_ID"];
    ipAddress = [RCCUserAttributeRequest getIPAddress];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"change uid"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData* stubData = [@"{\"email\" : \"bencheng@oursky.com\",\"user_id\" : \"1\",\"name\" : \"Ben Cheng\", \"uid\" : \"6543\"}" dataUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"%@",stubData);
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{
                                                                                       @"Content-type":@"application/json"
                                                                                       }];
    }];
    
    [library identifyWithEmail:@"test@example.com" userID:@"1234" callback:^(BOOL success, NSError *error) {
        [OHHTTPStubs removeAllStubs];
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            
            BOOL shouldApply = [request.URL.absoluteString isEqualToString:@"https://app.retain.cc/api/v1/users"];
            if (!shouldApply) return NO;

            NSError *error = nil;
            NSDictionary *bodyData = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:kNilOptions error:&error];
            XCTAssert([[bodyData objectForKey:@"uid"] isEqualToString:@"6543"], @"send correct data");
            XCTAssert(!error);
            
            return YES;
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            NSData* stubData = [@"{\"email\" : \"bencheng@oursky.com\",\"user_id\" : \"1\",\"name\" : \"Ben Cheng\",\"created_at\" : 1257553080,\"custom_data\" : {\"plan\" : \"pro\"},\"last_seen_ip\" : \"1.2.3.4\",\"last_seen_user_agent\" : \"ie6\",\"company_ids\" : [6, 10],\"last_impression_at\" : 1300000000}" dataUsingEncoding:NSUTF8StringEncoding];
            return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{
                                                                                           @"Content-type":@"application/json"
                                                                                           }];
        }];
        
        [library changeUserAttributes:@{}
                         callback:^(BOOL success, NSError *error) {
                             XCTAssert(success,@"Request failed, %@", error);
                             [expectation fulfill];
                         }];
    }];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            NSLog(@"test error: %@", error.localizedDescription);
        }
    }];
}

- (void)testChangeUserAttributes {
    
    __block NSString *ipAddress = @"";
    
    RetainCC *library = [[RetainCC alloc] initWithApiKey:@"API_KEY" appID:@"APP_ID"];
    ipAddress = [RCCUserAttributeRequest getIPAddress];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"receiving and send uid"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData* stubData = [@"{\"email\" : \"bencheng@oursky.com\",\"user_id\" : \"1\",\"name\" : \"Ben Cheng\",\"created_at\" : 1257553080,\"custom_data\" : {\"plan\" : \"pro\"},\"last_seen_ip\" : \"1.2.3.4\",\"last_seen_user_agent\" : \"ie6\",\"company_ids\" : [6, 10],\"last_impression_at\" : 1300000000}" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{
                                                                                       @"Content-type":@"application/json"
                                                                                       }];
    }];
    
    [library identifyWithEmail:@"test@example.com" userID:@"1234" callback:^(BOOL success, NSError *error) {
        [OHHTTPStubs removeAllStubs];
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            
            BOOL shouldApply = [request.URL.absoluteString isEqualToString:@"https://app.retain.cc/api/v1/users"];
            if (!shouldApply) return NO;
            
            NSDictionary *allHeaders = request.allHTTPHeaderFields;
            // check auth
            NSString *authString = [allHeaders objectForKey:@"Authorization"];
            XCTAssert(authString, @"No auth string found");
            authString = [authString substringFromIndex:[authString rangeOfString:@"Basic "].length];
            NSData *authData = [[NSData alloc]initWithBase64EncodedString:authString options:0];
            XCTAssert(authData, @"Auth data is not base63 encoded");
            NSString *decodedData = [[NSString alloc] initWithData:authData encoding:NSUTF8StringEncoding];
            XCTAssert([decodedData isEqualToString:@"APP_ID:API_KEY"]);
            
            // content type check
            XCTAssert([[allHeaders objectForKey:@"Content-type"] rangeOfString:@"application/json"].location != NSNotFound,@"Request Content-type should be json");
            XCTAssert([[request HTTPMethod] isEqualToString:@"POST"],"should use post");
            
            NSError *error = nil;
            NSDictionary *bodyData = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:kNilOptions error:&error];
            NSDictionary *shouldSend = @{
                                         @"email" : @"test@example.com",
                                         @"user_id" : @"1234",
                                         @"name" : @"Ben",
                                         @"custom_data" : @{
                                                 @"CUSTOM_KEY1" : @"CUSTOM_VALUE1",
                                                 @"CUSTOM_KEY2" : @"CUSTOM_VALUE2",
                                                 @"system_version" : [UIDevice currentDevice].systemVersion,
                                                 @"system_name" : [UIDevice currentDevice].systemName,
                                                 @"model" : [UIDevice currentDevice].model,
                                                 @"screen_size" : NSStringFromCGSize([UIScreen mainScreen].bounds.size),
                                                 @"scale" : [NSString stringWithFormat:@"%f",[UIScreen mainScreen].scale]
                                                 }.mutableCopy,
                                         @"last_seen_ip" : ipAddress,
                                         @"last_seen_user_agent" : @"iOS",
                                         @"last_impression_at" : [bodyData objectForKey:@"last_impression_at"]
                                         };
            if ([[UIScreen mainScreen] respondsToSelector:@selector(nativeBounds)]) {
                [[shouldSend objectForKey:@"custom_data"] setObject:NSStringFromCGSize([UIScreen mainScreen].nativeBounds.size) forKey:@"native_screen_size"];
            }
            if ([[UIScreen mainScreen] respondsToSelector:@selector(nativeScale)]) {
                [[shouldSend objectForKey:@"custom_data"] setObject:[NSString stringWithFormat:@"%f",[UIScreen mainScreen].nativeScale] forKey:@"native_scale"];
            }
            if (![shouldSend isEqualToDictionary:bodyData]) {
                NSLog(@"Change attributes ============ ");
                NSLog(@"%@",bodyData.description);
                NSLog(@"%@", shouldSend.description);
            }
            XCTAssert([bodyData isEqualToDictionary:shouldSend], @"send correct data");
            XCTAssert(!error);
            //        XCTAssert([[bodyData objectForKey:@"KEY1"] isEqualToString:@"VALUE1"]);
            //        XCTAssert([[bodyData objectForKey:@"KEY2"] isEqualToString:@"VALUE2"]);
            
            return YES;
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            NSData* stubData = [@"{\"email\" : \"bencheng@oursky.com\",\"user_id\" : \"1\",\"name\" : \"Ben Cheng\",\"created_at\" : 1257553080,\"custom_data\" : {\"plan\" : \"pro\"},\"last_seen_ip\" : \"1.2.3.4\",\"last_seen_user_agent\" : \"ie6\",\"company_ids\" : [6, 10],\"last_impression_at\" : 1300000000}" dataUsingEncoding:NSUTF8StringEncoding];
            return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{
                                                                                           @"Content-type":@"application/json"
                                                                                           }];
        }];
        
        [library changeUserAttributes:@{
                                        @"name" : @"Ben",
                                        @"CUSTOM_KEY1" : @"CUSTOM_VALUE1",
                                        @"CUSTOM_KEY2" : @"CUSTOM_VALUE2"
                                        }
                             callback:^(BOOL success, NSError *error) {
                                 XCTAssert(success,@"Request failed, %@", error);
                                 [expectation fulfill];
                             }];
    }];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            NSLog(@"test error: %@", error.localizedDescription);
        }
    }];
}

@end
