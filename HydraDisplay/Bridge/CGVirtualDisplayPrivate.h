//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  CGVirtualDisplayPrivate.h
//  Hydra Display
//
//  Reverse-engineered declarations for Apple's PRIVATE CoreGraphics
//  virtual-display classes. These are NOT public API. They have existed and
//  been broadly source-compatible across many macOS releases (this is the same
//  mechanism used by BetterDisplay, FreeDisplay, SimpleDisplay, etc.), but
//  Apple may change or remove them at any time. Because of this:
//
//    * Apps that use these symbols cannot ship on the Mac App Store.
//    * Always create instances defensively (see VirtualDisplayBridge.swift,
//      which checks class availability at runtime before touching them).
//
//  Header shape derived from the public class-dumps at
//  https://github.com/w0lfschild/macOS_headers (CoreGraphics).
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// A single resolution + refresh-rate the virtual display will advertise.
@interface CGVirtualDisplayMode : NSObject
@property (readonly, nonatomic) unsigned int width;
@property (readonly, nonatomic) unsigned int height;
@property (readonly, nonatomic) double refreshRate;
- (instancetype)initWithWidth:(unsigned int)width
                       height:(unsigned int)height
                  refreshRate:(double)refreshRate;
@end

/// Describes the (immutable) hardware identity of a virtual display before it
/// is created: name, EDID-like IDs, physical size and color primaries.
@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int serialNum;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) struct CGSize sizeInMillimeters;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) struct CGPoint redPrimary;
@property (nonatomic) struct CGPoint greenPrimary;
@property (nonatomic) struct CGPoint bluePrimary;
@property (nonatomic) struct CGPoint whitePoint;
@property (retain, nonatomic) dispatch_queue_t queue;
@property (copy, nonatomic) void (^terminationHandler)(id _Nullable, id _Nullable);
- (instancetype)init;
@end

/// The mutable settings (modes + HiDPI flag) applied to a live display.
@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic) unsigned int hiDPI;
@property (retain, nonatomic) NSArray *modes;
- (instancetype)init;
@end

/// A live virtual display. Created from a descriptor; configured via
/// -applySettings:. Releasing the object (or its terminationHandler firing)
/// tears the display down.
@interface CGVirtualDisplay : NSObject
@property (readonly, nonatomic) unsigned int displayID;
@property (readonly, nonatomic) unsigned int vendorID;
@property (readonly, nonatomic) unsigned int productID;
@property (readonly, nonatomic) unsigned int serialNum;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) unsigned int hiDPI;
@property (readonly, nonatomic) NSArray *modes;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

NS_ASSUME_NONNULL_END
