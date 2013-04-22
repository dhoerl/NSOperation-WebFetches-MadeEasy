
// FastEasyConcurrentWebFetches (TM)
// Copyright (C) 2012 by David Hoerl
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "ConcurrentOperation.h"

@interface ConcurrentOperation (DoesNotExist)

- (void)timer:(NSTimer *)t; // keeps the compiler happy

@end

@interface ConcurrentOperation ()
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong, readwrite) NSThread *thread;
@property(atomic, assign) BOOL done;

@end

@implementation ConcurrentOperation
@synthesize timer;
@synthesize thread;

- (void)setThreadPriority:(double)priority
{
	if(![self isFinished]) {
		[super setThreadPriority:priority];
	}
}

- (void)main
{
	BOOL isCancelled = [self isCancelled];
	if(isCancelled) {
		// NSLog(@"OPERATION CANCELLED: isCancelled=%d isHostUp=%d", isCancelled, isHostUDown);
		return;
	}

	BOOL allOK = [self setup] ? YES : NO;

	if(allOK) {
		while(!self.done) {
#ifndef NDEBUG
			BOOL ret = 
#endif
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
			assert(ret && "first assert");
		}
		//NSLog(@"DONE=%d", self.done);
	} else {
		[self finish];
	}
	[self cleanup];
}

- (id)setup
{
	thread	= [NSThread currentThread];	

	// makes runloop functional
	timer	= [NSTimer scheduledTimerWithTimeInterval:60*60 target:self selector:@selector(timer:) userInfo:nil repeats:NO];	

	return @"";
}

- (void)cleanup
{
	[timer invalidate], timer = nil;
	
	return;
}

- (void)cancel
{
	[super cancel];
	
	if([self isExecuting]) {
		[self performSelector:@selector(finish) onThread:thread withObject:nil waitUntilDone:NO];
	}
}

- (void)completed // subclasses to override then finally call super
{
	[self performSelector:@selector(finish) onThread:self.thread withObject:nil waitUntilDone:NO];
}

- (void)failed // subclasses to override then finally call super
{
	[self performSelector:@selector(finish) onThread:self.thread withObject:nil waitUntilDone:NO];
}

- (void)finish // subclasses to override then finally call super, for cleanup
{
	self.done = YES;
}

- (void)dealloc
{
	NSLog(@"Concurrent Operation Dealloc");
}

@end

