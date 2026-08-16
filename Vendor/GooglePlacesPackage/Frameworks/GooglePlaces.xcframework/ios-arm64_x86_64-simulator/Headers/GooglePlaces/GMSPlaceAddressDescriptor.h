//
//  GMSPlaceAddressDescriptor.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <Foundation/Foundation.h>



#import "GMSPlaceArea.h"
#import "GMSPlaceLandmark.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A relational description of a location.
 *
 * Includes a ranked set of nearby landmarks and precise containing areas and their
 * relationship to the target location.
 */
@interface GMSPlaceAddressDescriptor : NSObject

/**
 * A ranked list of nearby landmarks.
 *
 * The most recognizable and nearby landmarks are ranked first.
 */
@property(nonatomic, nonnull, readonly) NSArray<GMSPlaceLandmark *> *landmarks;

/**
 * A ranked list of containing or adjacent areas.
 *
 * The most recognizable and precise areas are ranked first.
 */
@property(nonatomic, nonnull, readonly) NSArray<GMSPlaceArea *> *areas;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
