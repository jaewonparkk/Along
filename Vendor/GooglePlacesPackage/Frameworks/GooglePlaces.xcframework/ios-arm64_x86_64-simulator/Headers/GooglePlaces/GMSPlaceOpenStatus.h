//
//  GMSPlaceOpenStatus.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Describes the current open status of a place. */
typedef NS_ENUM(NSInteger, GMSPlaceOpenStatus) {
  /** The place open status is unknown. */
  GMSPlaceOpenStatusUnknown,
  /** The place is open. */
  GMSPlaceOpenStatusOpen,
  /** The place is closed. */
  GMSPlaceOpenStatusClosed,
};

NS_ASSUME_NONNULL_END
