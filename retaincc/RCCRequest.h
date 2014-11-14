//
//  RCCRequest.h
//  retaincc
//
//  Created by b123400 on 3/10/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A class to wrap requests.
 * This class is designed to be subclassed, using this class directly is useless.
 * This class comforts to NSCoding, it can be transformed into NSData, so requests can be saved to disk and retry later.
 */
@interface RCCRequest : NSObject<NSCoding>

/**
 * UserID from RetainCC, stored in request so things will not mess up even if user switches account.
 */
@property (strong, nonatomic) NSString *userID;
/**
 * Email from RetainCC, stored in request so things will not mess up even if user switches account.
 */
@property (strong, nonatomic) NSString *email;

/**
 * Uid from RetainCC, stored in request to identify anonymous users
 */
@property (strong, nonatomic) NSString *uid;

/**
 * Create a RCCRequest instance.
 *
 * It requires apiKey and appID from RetainCC, stored in request so developer can use multiple instance at the same time.
 * @param apiKey The Api key from RetainCC
 * @param appID ID from RetainCC
 */
- (id)initWithApiKey:(NSString*)apiKey appID:(NSString*)appID;

/**
 * Send the request.
 * This method can be called multiple times.
 *
 * @param callback The callback will be called when the request is finished.
 */
- (void)send:(void(^)(BOOL success, NSError *error))callback;

/**
 * Create a request for subclasses
 * Prepare basic auth for the request.
 */
- (NSMutableURLRequest*)authedRequest;
- (NSMutableURLRequest*)authedRequestWithBody:(NSData*)data;
- (NSMutableURLRequest*)authedRequestWithJSON:(NSDictionary*)json;

/**
 * Send request and callback, should be called by subclasses
 */
- (void)sendRequest:(NSURLRequest*)request callback:(void(^)(BOOL success, NSError *error))callback;

@end
