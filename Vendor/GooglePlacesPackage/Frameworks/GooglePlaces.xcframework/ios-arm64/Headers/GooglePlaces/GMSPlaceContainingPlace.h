//
//  GMSPlaceContainingPlace.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

/** Represents a parent location that holds another place. */
@interface GMSPlaceContainingPlace : NSObject

/** The resource name of the place. */
@property(nonatomic, readonly, nullable) NSString *resourceName;

/** The ID of the place. */
@property(nonatomic, readonly, nullable) NSString *placeID;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
