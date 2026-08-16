//
//  GMSPlaceLandmark.h
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
 * Defines the spatial relationship between the target location and the landmark.
 */
typedef NS_ENUM(NSInteger, GMSPlaceLandmarkSpatialRelationship) {
  /**
   * The landmark is near the target. This is the default relationship when nothing more specific
   * below applies.
   */
  GMSPlaceLandmarkSpatialRelationshipNear = 0,

  /** The target is within the landmark. */
  GMSPlaceLandmarkSpatialRelationshipWithin,

  /** The landmark is beside the target. */
  GMSPlaceLandmarkSpatialRelationshipBeside,

  /** The landmark is across the road from the target. */
  GMSPlaceLandmarkSpatialRelationshipAcrossTheRoad,

  /** The landmark is down the road from the target. */
  GMSPlaceLandmarkSpatialRelationshipDownTheRoad,

  /** The landmark is around the corner from the target. */
  GMSPlaceLandmarkSpatialRelationshipAroundTheCorner,

  /** The landmark is behind the target. */
  GMSPlaceLandmarkSpatialRelationshipBehind,
};

/**
 * Basic landmark information and the landmark's relationship with the target location.
 *
 * Landmarks are prominent places that can be used to describe a location.
 */
@interface GMSPlaceLandmark : NSObject

/** The landmark's resource name. */
@property(nonatomic, nullable, readonly) NSString *resourceName;

/** The landmark's place ID. */
@property(nonatomic, nullable, readonly) NSString *placeID;

/** The landmark's display name. */
@property(nonatomic, nullable, readonly) NSString *displayName;

/** The landmark's display name language code. */
@property(nonatomic, nullable, readonly) NSString *displayNameLanguageCode;

/**
 * A set of type tags for this landmark.
 * For a complete list of possible values, see
 * https://developers.google.com/maps/documentation/places/web-service/place-types.
 */
@property(nonatomic, nullable, readonly) NSArray<NSString *> *types;

/** Defines the spatial relationship between the target location and the landmark. */
@property(nonatomic, assign, readonly) GMSPlaceLandmarkSpatialRelationship spatialRelationship;

/**
 * The straight line distance, in meters, between the center point of the target and
 * the center point of the landmark.
 *
 * In some situations, this value can be longer than `travelDistanceMeters`.
 */
@property(nonatomic, nullable, readonly) NSNumber *straightLineDistanceMeters;

/**
 * The travel distance, in meters, along the road network from the target to the
 * landmark, if known.
 *
 * This value does not take into account the mode of transportation, such as walking, driving, or
 * biking.
 */
@property(nonatomic, nullable, readonly) NSNumber *travelDistanceMeters;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
