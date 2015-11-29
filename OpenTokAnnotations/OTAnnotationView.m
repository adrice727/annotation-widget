//
//  OTAnnotationView.m
//  Annotations Demo
//
//  Created by Trevor Boyer on 8/3/15.
//  Copyright (c) 2015 TokBox Inc. All rights reserved.
//

#import "OTAnnotationView.h"
#import "OTAnnotationAnalytics.h"
#import "OTAnnotationButtonItem.h"
#import "OTColorButtonItem.h"
#import "OTPath.h"
#import "UIColor+HexString.h"
#import "OTShape.h"
#import "OTAnnotationVideoRender.h"

#define kTolerance 5

@implementation OTAnnotationView {
    NSMutableArray *_paths;
    CGPoint _currentPoint;
    CGPoint _lastPoint;
    CGPoint _startPoint;
    
    UIColor *_color;
    
    CGFloat _lineWidth;
    
    OTSubscriber *_subscriber;
    OTPublisher *_publisher;
    
    NSString *_sessionId;
    NSString *_mycid;
    NSString *_canvasId;
    
    CGSize _videoDimensions;
    
    Boolean _mirrored;
    
    Boolean _isFirstPoint;
    
    OTAnnotationButtonItem *_selectedItem;
    
    Boolean _isDrawing;
    
    UITapGestureRecognizer *_tap;
}

- (id)initWithSubscriber:(OTSubscriber *)subscriber {
    if (self = [super initWithFrame:subscriber.view.frame]) {
        _subscriber = subscriber;
        _sessionId = subscriber.session.sessionId;
        _mycid = subscriber.session.connection.connectionId;
        _mirrored = false;
        
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (subscriber.stream.connection.connectionId == nil) {
                /* wait */
            }
            
            dispatch_async( dispatch_get_main_queue(), ^{
                _canvasId = subscriber.stream.connection.connectionId;
                _videoDimensions = subscriber.stream.videoDimensions;
                [self setupView];
            });
        });
    }
    return self;
}

- (id)initWithPublisher:(OTPublisher *)publisher {
    if (self = [super initWithFrame:publisher.view.frame]) {
        _publisher = publisher;
        _sessionId = publisher.session.sessionId;
        _mycid = publisher.session.connection.connectionId;
        _mirrored = ((OTAnnotationVideoRender*)publisher.videoRender).mirroring;
        
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (publisher.stream.connection.connectionId == nil) {
                /* wait */
            }
            
            dispatch_async( dispatch_get_main_queue(), ^{
                _canvasId = publisher.stream.connection.connectionId;
                _videoDimensions = publisher.stream.videoDimensions;
                [self setupView];
            });
        });
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    [self setMultipleTouchEnabled:NO];
    [self setBackgroundColor:[UIColor clearColor]];
    
    _isFirstPoint = false;
    
    _paths = [NSMutableArray array];
    
    _lineWidth = 2.f;
    
    [self createPath:_mycid];
    
    // Ensure the canvas is always the top layer
    [self.superview bringSubviewToFront:self];
    self.userInteractionEnabled = true;
}

-(OTPath*)activePath {
    return [_paths lastObject];
}

- (void)drawRect:(CGRect)rect {
    for (OTPath* path in _paths) {
        [path.color setStroke];
        [path.bezierPath stroke];
    }
    
    if (_isDrawing) {
        if (_selectedItem != nil && _selectedItem.points != nil) {
            [self drawPoints:_selectedItem.points withSmoothing:_selectedItem.enableSmoothing];
        }
    }
}

- (void)drawPoints:(NSArray*)points withSmoothing:(Boolean)smoothingEnabled {
    float dx = fabsf(_currentPoint.x - _lastPoint.x);
    float dy = fabsf(_currentPoint.y - _lastPoint.y);
    
    if (dx >= kTolerance || dy >= kTolerance) {
        CGPoint scale = [self scaleForPoints: points];
        
        OTPath* path = [[OTPath alloc] init];
        [path setColor:_color];
        [path.bezierPath setLineWidth:_lineWidth];
        
        if (_selectedItem.points.count == 2) {
            // We have a line
            [path.bezierPath moveToPoint: _startPoint];
            [path.bezierPath addLineToPoint: _currentPoint];
        } else {
            float lastX = -1;
            float lastY = -1;
            for (int i = 0; i < _selectedItem.points.count; i++) {
                // Scale the points according to the difference between the start and end points
                float pointX = _startPoint.x + (scale.x * [(NSValue*)[points objectAtIndex:i] CGPointValue].x);
                float pointY = _startPoint.y + (scale.y * [(NSValue*)[points objectAtIndex:i] CGPointValue].y);
                
                if (smoothingEnabled) {
                    if (i == 0) {
                        // Do nothing
                    } else if (i == 1) {
                        [path.bezierPath moveToPoint: CGPointMake((pointX + lastX) / 2, (pointY + lastY) / 2)];
                    } else {
                        [path.bezierPath addQuadCurveToPoint: CGPointMake((pointX + lastX) / 2, (pointY + lastY) / 2) controlPoint: CGPointMake(lastX, lastY)];
                        
                        if (i == _selectedItem.points.count-1) {
                            [path.bezierPath closePath];
                        }
                    }
                } else {
                    if (i == 0) {
                        [path.bezierPath moveToPoint: CGPointMake(pointX, pointY)];
                    } else {
                        [path.bezierPath addLineToPoint: CGPointMake(pointX, pointY)];
                        
                        if (i == _selectedItem.points.count-1) {
                            [path.bezierPath closePath];
                        }
                    }
                }
                
                lastX = pointX;
                lastY = pointY;
            }
        }
        
        // Only drawn temporarily
        [path.color setStroke];
        [path.bezierPath stroke];
    }
}

- (CGPoint)scaleForPoints: (NSArray*)points {
    // _currentPoint refers to the end point of the enclosing rectangle (touch up)
    float minX = FLT_MAX;
    float minY = FLT_MAX;
    float maxX = 0;
    float maxY = 0;
    
    for (int i = 0; i < _selectedItem.points.count; i++) {
        CGPoint point = [(NSValue*)[points objectAtIndex:i] CGPointValue];
        
        if (point.x < minX) {
            minX = point.x;
        } else if (point.x > maxX) {
            maxX = point.x;
        }
        
        if (point.y < minY) {
            minY = point.y;
        } else if (point.y > maxY) {
            maxY = point.y;
        }
    }
    float dx = fabsf(maxX - minX);
    float dy = fabsf(maxY - minY);
    
    float scaleX = (_currentPoint.x - _startPoint.x) / dx;
    float scaleY = (_currentPoint.y - _startPoint.y) / dy;
    
    return CGPointMake(scaleX, scaleY);
}

- (void)createPath:(NSString*)canvasId {
    OTPath* path = [[OTPath alloc] init];
    [path setColor:_color];
    [path.bezierPath setLineWidth:_lineWidth];
    [path setCanvasId:_mycid];
    [_paths addObject:path];
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [self createPath:_mycid];
}

- (void)setLineWidth:(CGFloat)lineWidth {
    _lineWidth = lineWidth;
    [self createPath:_mycid];
}

- (void)clearCanvas:(NSString*)canvasId incoming:(Boolean)incoming {
    NSMutableArray *removed = [NSMutableArray array];
    for (OTPath* path in _paths) {
        if ([path.canvasId isEqualToString:canvasId]) {
            [removed addObject:path];
        }
    }
    [_paths removeObjectsInArray:removed];
    [self setNeedsDisplay];
    
    // Initialize a new path so that we can still draw
    OTPath* path = [[OTPath alloc] init];
    [path setColor:_color];
    [path.bezierPath setLineWidth:_lineWidth];
    [path setCanvasId:_mycid];
    [_paths addObject:path];
    
    if (!incoming) {
        [self sendUpdate:nil forType:@"otAnnotation_clear"];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    _startPoint = point;
    
    _isFirstPoint = true;
    
    [self createPath:_mycid];
    
    if (_selectedItem.points != nil) {
        _isDrawing = true;
    } else {
        [self startTouch:point];
    }
}

- (void)startTouch:(CGPoint)point {
    [[self activePath].bezierPath moveToPoint:point];
    _lastPoint = point;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    _currentPoint = point;
    
    if ([_selectedItem.identifier isEqualToString:@"ot_pen"]) {
        [self moveTouch:point smoothingEnabled:_selectedItem.enableSmoothing startPoint:_isFirstPoint endPoint:false incoming:false];
        
        NSDictionary* data = @{
                                   @"action" : @"Pen",
                                   @"variation" : @"Draw",
                                   @"payload" : @"",
                                   @"sessionId" : _sessionId,
                                   @"partnerId" : @"",
                                   @"connectionId" : _mycid
                               };
        
        [OTAnnotationAnalytics logEvent:data];
    } else {
        if (_selectedItem.points != nil) {
            [self setNeedsDisplay];
        }
    }
    
    _isFirstPoint = false;
}

- (void)moveTouch:(CGPoint)point {
    [self moveTouch:point smoothingEnabled:false startPoint:_isFirstPoint endPoint:nil incoming:false];
}

- (void)moveTouch:(CGPoint)point smoothingEnabled:(Boolean)smoothingEnabled {
    [self moveTouch:point smoothingEnabled:smoothingEnabled startPoint:_isFirstPoint endPoint:nil incoming:true];
}

- (void)moveTouch:(CGPoint)point smoothingEnabled:(Boolean)smoothingEnabled startPoint:(Boolean)startPoint endPoint:(Boolean)endPoint incoming:(Boolean) incoming {
    if (smoothingEnabled) {
        [[self activePath].bezierPath addQuadCurveToPoint: CGPointMake((point.x + _lastPoint.x) / 2, (point.y + _lastPoint.y) / 2) controlPoint: _lastPoint];
    } else {
        [[self activePath].bezierPath addLineToPoint:point];
    }
    [self setNeedsDisplay];
    
    if (!incoming) {
//        NSLog(@"%f, %f", _lastPoint.x, _lastPoint.y);
//        NSLog(@"%f, %f", point.x, point.y);
        
        // INFO: This should only be an issue for publishers, but check subscribers too just in case
        if (_canvasId == nil) {
            if (_publisher != nil) {
                _canvasId = _publisher.stream.connection.connectionId;
                _videoDimensions = _publisher.stream.videoDimensions;
            } else if (_subscriber != nil) {
                _canvasId = _subscriber.stream.connection.connectionId;
                _videoDimensions = _subscriber.stream.videoDimensions;
            }
            
            // Make sure we update the id of the active path
            OTPath* path = [self activePath];
            if (path.canvasId == nil) {
                path.canvasId = _canvasId;
            }
        }
        
        // Send the signal
        NSDictionary* jsonObject = @{
                                         @"id" : _canvasId,
                                         @"fromId" : _mycid,
                                         @"fromX" : [NSNumber numberWithFloat:_lastPoint.x],
                                         @"fromY" : [NSNumber numberWithFloat:_lastPoint.y],
                                         @"toX" : [NSNumber numberWithFloat:point.x],
                                         @"toY" : [NSNumber numberWithFloat:point.y],
                                         @"color" : [UIColor hexStringFromColor:_color],
                                         @"lineWidth" : [NSNumber numberWithFloat:_lineWidth],
                                         @"videoWidth" : [NSNumber numberWithFloat:_videoDimensions.width],
                                         @"videoHeight" : [NSNumber numberWithFloat:_videoDimensions.height],
                                         @"canvasWidth" : [NSNumber numberWithFloat:self.frame.size.width],
                                         @"canvasHeight" : [NSNumber numberWithFloat:self.frame.size.height],
                                         @"mirrored" : _mirrored ? @true : @false,
                                         @"smoothed" : _selectedItem.enableSmoothing ? @true : @false,
                                         @"startPoint" : startPoint ? @true : @false,
                                         @"endPoint" : endPoint ? @true : @false
                                     };
        
        NSLog(@"%@", jsonObject);
        
        NSArray* jsonArray = [NSArray arrayWithObjects:jsonObject, nil];
        
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonArray
                                                           options:0
                                                             error:&error];
        
        NSString* update = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        [self sendUpdate:update forType:@"otAnnotation_pen"];
    }
    
    _lastPoint = point;
}

- (void)drawShape {
    if (_selectedItem.points != nil) {
        _isDrawing = false;
        
        // Make sure we update the id of the active path
        OTPath* path = [self activePath];
        if (path.canvasId == nil) {
            path.canvasId = _canvasId;
        }
        
        if (_selectedItem.points.count == 2) {
            // We have a line
            [self startTouch: CGPointMake(_startPoint.x, _startPoint.y)];
            [self moveTouch: CGPointMake(_currentPoint.x, _currentPoint.y) smoothingEnabled:_selectedItem.enableSmoothing startPoint:true endPoint:true incoming:false];
        } else {
            CGPoint scale = [self scaleForPoints: _selectedItem.points];

            for (int i = 0; i < _selectedItem.points.count; i++) {
                CGPoint point = [(NSValue*)[_selectedItem.points objectAtIndex:i] CGPointValue];
                
                BOOL startPoint = false;
                BOOL endPoint = false;
                
                // Scale the points according to the difference between the start and end points
                float pointX = _startPoint.x + (scale.x * point.x);
                float pointY = _startPoint.y + (scale.y * point.y);

                if (_selectedItem.enableSmoothing) {
                    if (i == 0) {
                        startPoint = true;
                    } else if (i == 1) {
                        [[self activePath].bezierPath moveToPoint:CGPointMake((pointX + _lastPoint.x) / 2, (pointY + _lastPoint.y) / 2)];
                    } else {
                        [[self activePath].bezierPath addQuadCurveToPoint:CGPointMake((pointX + _lastPoint.x) / 2, (pointY + _lastPoint.y) / 2) controlPoint:CGPointMake(_lastPoint.x, _lastPoint.y)];
                        
                        if (i == _selectedItem.points.count-1) {
                            [[self activePath].bezierPath closePath];
                            endPoint = true;
                        }
                    }
                } else {
                    if (i == 0) {
                        startPoint = true;
                        _lastPoint.x = pointX;
                        _lastPoint.y = pointY;
                        [self startTouch: CGPointMake(pointX, pointY)];
                    } else {
                        [self moveTouch: CGPointMake(pointX, pointY) smoothingEnabled:false startPoint:false endPoint:false incoming:false];
                        
                        if (i == _selectedItem.points.count-1) {
                            [[self activePath].bezierPath closePath];
                            endPoint = true;
                        }
                    }
                }

                [self sendUpdate:[self buildSignalFromPoint: CGPointMake(pointX, pointY) startPoint:startPoint endPoint:endPoint] forType:@"otAnnotation_pen"];

                _lastPoint.x = pointX;
                _lastPoint.y = pointY;
            }
        }
        
        NSDictionary* data = @{
                                   @"action" : @"Shape",
                                   @"variation" : @"Draw",
                                   @"payload" : @"",
                                   @"sessionId" : _sessionId,
                                   @"partnerId" : @"",
                                   @"connectionId" : _mycid
                               };
        
        [OTAnnotationAnalytics logEvent:data];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([_selectedItem.identifier isEqualToString:@"ot_pen"]) {
        [self touchesMoved:touches withEvent:event];
    } else {
        [self drawShape];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (NSString*)buildSignalFromPoint:(CGPoint)point startPoint:(BOOL)startPoint endPoint:(Boolean)endPoint {
    if (_publisher != nil) {
        _canvasId = _publisher.stream.connection.connectionId;
        _videoDimensions = _publisher.stream.videoDimensions;
    } else if (_subscriber != nil) {
        _canvasId = _subscriber.stream.connection.connectionId;
        _videoDimensions = _subscriber.stream.videoDimensions;
    }
    
    // Send the signal
    NSDictionary* jsonObject = @{
                                     @"id" : _canvasId,
                                     @"fromId" : _mycid,
                                     @"fromX" : [NSNumber numberWithFloat:_lastPoint.x],
                                     @"fromY" : [NSNumber numberWithFloat:_lastPoint.y],
                                     @"toX" : [NSNumber numberWithFloat:point.x],
                                     @"toY" : [NSNumber numberWithFloat:point.y],
                                     @"color" : [UIColor hexStringFromColor:_color],
                                     @"lineWidth" : [NSNumber numberWithFloat:_lineWidth],
                                     @"videoWidth" : [NSNumber numberWithFloat:_videoDimensions.width],
                                     @"videoHeight" : [NSNumber numberWithFloat:_videoDimensions.height],
                                     @"canvasWidth" : [NSNumber numberWithFloat:self.frame.size.width],
                                     @"canvasHeight" : [NSNumber numberWithFloat:self.frame.size.height],
                                     @"mirrored" : _mirrored ? @true : @false,
                                     @"smoothed" : _selectedItem.enableSmoothing ? @true : @false,
                                     @"startPoint" : startPoint ? @true : @false,
                                     @"endPoint" : endPoint ? @true : @false
                                 };
    
    NSArray* jsonArray = [NSArray arrayWithObjects:jsonObject, nil];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonArray
                                                       options:0
                                                         error:&error];
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)didReceiveSignal:(NSString*)signal withType:(NSString*)type fromConnection:(OTConnection*)connection {
    if (![connection.connectionId isEqualToString:_mycid]) {
        if ([type isEqualToString:@"otAnnotation_pen"]) {
            NSError *jsonError;
            NSData *objectData = [signal dataUsingEncoding:NSUTF8StringEncoding];
            NSArray* jsonArray = [NSJSONSerialization JSONObjectWithData:objectData
                                            options:NSJSONReadingMutableContainers
                                              error:&jsonError];
            
            for (NSDictionary* json in jsonArray) {
                NSString* canvasId = json[@"id"];
                
                if (_canvasId == nil) {
                    if (_publisher != nil) {
                        _canvasId = _publisher.stream.connection.connectionId;
                        _videoDimensions = _publisher.stream.videoDimensions;
                    } else if (_subscriber != nil) {
                        _canvasId = _subscriber.stream.connection.connectionId;
                        _videoDimensions = _subscriber.stream.videoDimensions;
                    }
                }
                
                if ([_canvasId isEqualToString:canvasId]) {
                    Boolean signalMirrored = [json[@"mirrored"] boolValue];

//                    NSLog(@"CanvasOffset CanvasSize: %f, %f", self.frame.size.width, self.frame.size.height);
                    
                    float scale = 1;
                    
                    CGSize canvas = CGSizeMake(self.frame.size.width, self.frame.size.height);
                    CGSize video = CGSizeMake(self.frame.size.width, self.frame.size.height);
                    CGSize iCanvas = CGSizeMake([(NSNumber*)json[@"canvasWidth"] floatValue], [(NSNumber*)json[@"canvasHeight"] floatValue]);
                    CGSize iVideo = CGSizeMake([(NSNumber*)json[@"videoWidth"] floatValue], [(NSNumber*)json[@"videoHeight"] floatValue]);
                    
//                    NSLog(@"CanvasOffset Sizes [Canvas: %f, %f Video: %f, %f iCanvas: %f, %f iVideo: %f, %f]",
//                            canvas.width, canvas.height,
//                            video.width, video.height,
//                            iCanvas.width, iCanvas.height,
//                            iVideo.width, iVideo.height);
                
                    float canvasRatio = canvas.width / canvas.height;
                    float videoRatio = video.width / video.height;
                    float iCanvasRatio = iCanvas.width / iCanvas.height;
                    float iVideoRatio = iVideo.width / iVideo.height;
                    
                    /**
                     * This assumes that if the width is the greater value, video frames
                     * can be scaled so that they have equal widths, which can be used to
                     * find the offset in the y axis. Therefore, the offset on the x axis
                     * will be 0. If the height is the greater value, the offset on the y
                     * axis will be 0.
                     */
                    if (canvasRatio < 0) {
                        scale = canvas.width / iCanvas.width;
                    } else {
                        scale = canvas.height / iCanvas.height;
                    }
                    
//                    NSLog(@"CanvasOffset Scale: %f", scale);
                    
                    // FIXME If possible, the scale should also scale the line width (use a min width value?)
                    
                    float centerX = canvas.width / 2;
                    float centerY = canvas.height / 2;
                    
                    float iCenterX = iCanvas.width / 2;
                    float iCenterY = iCanvas.height / 2;
                    
                    float fromX = centerX - (scale * (iCenterX - [(NSNumber*) json[@"fromX"] floatValue]));
                    float fromY = centerY - (scale * (iCenterY - [(NSNumber*) json[@"fromY"] floatValue]));
                    
                    float toX = centerX - (scale * (iCenterX - [(NSNumber*) json[@"toX"] floatValue]));
                    float toY = centerY - (scale * (iCenterY - [(NSNumber*) json[@"toY"] floatValue]));
                    
//                    NSLog(@"CanvasOffset From: %f, %f", fromX, fromY);
//                    NSLog(@"CanvasOffset To: %f, %f", toX, toY);
                    
                    if (signalMirrored) {
                        fromX = self.frame.size.width - fromX;
                        toX = self.frame.size.width - toX;
                    }
                    
                    if (_mirrored) {
                        // Revert (Double negative)
                        fromX = self.frame.size.width - fromX;
                        toX = self.frame.size.width - toX;
                    }
                    
                    Boolean firstPoint = [json[@"startPoint"] boolValue];
                    Boolean secondPoint = false;
                    Boolean endPoint = [json[@"endPoint"] boolValue];
                    
                    if (firstPoint) {
                        OTPath* path = [[OTPath alloc] init];
                        [path setColor:[UIColor colorFromHexString: json[@"color"]]];
                        [path.bezierPath setLineWidth:[(NSNumber *)json[@"lineWidth"] floatValue]];
                        [path setCanvasId:connection.connectionId];
                        [_paths addObject:path];
                        
                        _isFirstPoint = true;
                    } else {
                        if (_isFirstPoint) {
                            secondPoint = true;
                            _isFirstPoint = false;
                        }
                    }
                    
                    Boolean smoothingEnabled = [json[@"smoothed"] boolValue];
                    
                    if (smoothingEnabled) {
                        if (firstPoint) {
                            _lastPoint.x = toX;
                            _lastPoint.y = toY;
                        } else if (secondPoint) {
                            [self startTouch: CGPointMake((toX + _lastPoint.x) / 2, (toY + _lastPoint.y) / 2)];
                        } else {
                            _lastPoint.x = fromX;
                            _lastPoint.y = fromY;
                            [self moveTouch: CGPointMake(toX, toY) smoothingEnabled:true];
                        }
                    } else {
                        if (firstPoint && endPoint) {
                            [self startTouch: CGPointMake(fromX, fromY)];
                            [self moveTouch: CGPointMake(toX, toY) smoothingEnabled:false];
                            [[self activePath].bezierPath closePath];
                        } else if (firstPoint) {
                            [self startTouch: CGPointMake(fromX, fromY)];
                        } else if (endPoint) {
                            [self moveTouch: CGPointMake(toX, toY) smoothingEnabled:false];
                            [[self activePath].bezierPath closePath];
                        } else {
                            [self moveTouch: CGPointMake(toX, toY) smoothingEnabled:false];
                        }
                        
                        // FIXME: Need to know if we have an end point so we can close the path
                    }
                }
            }
        } else if ([type isEqualToString:@"otAnnotation_clear"]) {
            [self clearCanvas:connection.connectionId incoming:true];
        }
    }
}

- (void)sendUpdate:(NSString *)update forType:(NSString *)type {
    NSError *error;
    
    if (_publisher != nil) {
        [_publisher.session signalWithType:type string:update connection:nil error:&error];
    } else if (_subscriber != nil) {
        [_subscriber.session signalWithType:type string:update connection:nil error:&error];
    } else {
        [NSException raise:@"Invalid publisher/subscriber" format:@"Please pass either a subscriber or publisher into the OTAnnotationView."];
    }
}

- (UIImage*)captureScreenshot {
    NSLog(@"Capturing screenshot");
    CGSize imageSize = CGSizeZero;
    
    imageSize = [UIScreen mainScreen].bounds.size;
    
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    
    UIView* videoView;
    
    if (_publisher != nil) {
        videoView = _publisher.view;
    } else if (_subscriber != nil) {
        videoView = _subscriber.view;
    }
    
    // First, draw the video
    if ([videoView respondsToSelector:
         @selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [videoView drawViewHierarchyInRect:videoView.bounds afterScreenUpdates:NO];
    } else {
        [videoView.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    
    // Then, overlay the annotations on top
    if ([self respondsToSelector:
         @selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [self drawViewHierarchyInRect:videoView.bounds afterScreenUpdates:NO];
    } else {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Include a "flash" animation
    UIView* flash = [[UIView alloc] initWithFrame:self.bounds];
    flash.backgroundColor = [UIColor whiteColor];
    [self addSubview:flash];
    
    [UIView animateWithDuration:0.5 animations:^{
        flash.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        [flash removeFromSuperview];
    }];
    
    [toolbar didCaptureImage:image forConnection:_canvasId];
    
    NSDictionary* data = @{
                               @"action" : @"Capture",
                               @"variation" : @"",
                               @"payload" : @"",
                               @"sessionId" : _sessionId,
                               @"partnerId" : @"",
                               @"connectionId" : _mycid
                           };
    
    [OTAnnotationAnalytics logEvent:data];
    
    return image;
}

- (void)didTapAnnotationItem:(UIBarButtonItem *)sender {
    // INFO: The color setter is handled in the toolbar, not here
    
    [self removeGestureRecognizer:_tap];
    
    if ([sender isKindOfClass: OTAnnotationButtonItem.self]) {
        OTAnnotationButtonItem* item = (OTAnnotationButtonItem*) sender;
        
        if ([item.identifier isEqualToString:@"ot_clear"]) {
            [self clearCanvas: _mycid incoming:false];
        } else if ([item.identifier isEqualToString:@"ot_capture"]) {
            _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(captureScreenshot)];
            _tap.numberOfTapsRequired = 1;
            [self addGestureRecognizer:_tap];
            
            _selectedItem = nil;
        } else if ([item.identifier rangeOfString:@"ot_line_width"].location != NSNotFound) {
            /* Do nothing */
        } else {
            if ([item.identifier isEqualToString:@"ot_arrow"]) {
                item.points = [OTShape arrow];
            } else if ([item.identifier isEqualToString:@"ot_rectangle"]) {
                item.points = [OTShape rectangle];
            } else if ([item.identifier isEqualToString:@"ot_oval"]) {
                item.points = [OTShape oval];
                item.enableSmoothing = true;
            } else if ([item.identifier isEqualToString:@"ot_line"]) {
                item.points = [OTShape line];
            }
            _selectedItem = item;
        }

    }
}

@end
