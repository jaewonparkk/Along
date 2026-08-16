//
//  GMSPlaceArea.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

/**
 * Defines the spatial relationship between the target location and the area.
 */
typedef NS_ENUM(NSInteger, GMSPlaceAreaContainment) {
  /** The containment relationship is unspecified. */
  GMSPlaceAreaContainmentUnspecified = 0,

  /** The target location is within the area. */
  GMSPlaceAreaContainmentWithin,

  /** The target location is on the outskirts of the area. */
  GMSPlaceAreaContainmentOutskirts,

  /** The target location is near the area. */
  GMSPlaceAreaContainmentNear,
};

/**
 * Area information and the area's relationship with the target location.
 *
 * Areas include precise sublocality, neighborhoods, and large compounds that are
 * useful for describing a location.
 */
@interface GMSPlaceArea : NSObject

/** The area's resource name. */
@property(nonatomic, nullable, readonly) NSString *resourceName;

/** The area's place ID. */
@property(nonatomic, nullable, readonly) NSString *placeID;

/** The area's display name. */
@property(nonatomic, nullable, readonly) NSString *displayName;

/** The area's display name language code. */
@property(nonatomic, nullable, readonly) NSString *displayNameLanguageCode;

/**
 * Defines the spatial relationship between the target location and the area.
 * Defaults to GMSPlaceAreaContainmentUnspecified if the relationship is not defined.
 */
@property(nonatomic, assign, readonly) GMSPlaceAreaContainment containment;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
