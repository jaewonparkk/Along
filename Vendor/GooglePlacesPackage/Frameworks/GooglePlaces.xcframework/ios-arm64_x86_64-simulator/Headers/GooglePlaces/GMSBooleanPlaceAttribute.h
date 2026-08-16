//
//  GMSBooleanPlaceAttribute.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Describes whether a place’s boolean attribute is available or not. */
typedef NS_ENUM(NSInteger, GMSBooleanPlaceAttribute) {
  /** The place's attribute has not been requested yet, or not known. */
  GMSBooleanPlaceAttributeUnknown,
  /** The place’s attribute is True. */
  GMSBooleanPlaceAttributeTrue,
  /** The place’s attribute is False. */
  GMSBooleanPlaceAttributeFalse,
};

NS_ASSUME_NONNULL_END
