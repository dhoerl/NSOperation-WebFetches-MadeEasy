
// FastEasyConcurrentWebFetches (TM)
// Copyright (C) 2012-2013 by David Hoerl
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

#import "OperationsRunnerProtocol.h"

@protocol OperationsRunnerProtocol;
@class ConcurrentOperation;

typedef enum { msgDelOnMainThread=0, msgDelOnAnyThread, msgOnSpecificThread, msgOnSpecificQueue } msgType;

@interface OperationsRunner : NSObject
@property (nonatomic, assign) msgType msgDelOn;					// how to message delegate, defaults to MainThread
@property (nonatomic, weak) NSThread *delegateThread;			// where to message delegate, sets msgDelOn->msgOnSpecificThread
@property (nonatomic, assign) dispatch_queue_t delegateQueue;	// where to message delegate, sets msgDelOn->msgOnSpecificQueue
@property (nonatomic, assign) BOOL noDebugMsgs;					// suppress debug messages
@property (nonatomic, assign) long priority;					// targets the internal GCD queue doleing out the operations
@property (nonatomic, assign) NSUInteger maxOps;				// set the NSOperationQueue's maxConcurrentOperationCount

- (id)initWithDelegate:(id <OperationsRunnerProtocol>)del;

- (void)runOperation:(ConcurrentOperation *)op withMsg:(NSString *)msg;	// to submit an operation

- (NSUInteger)operationsCount;	// now returns immediately

- (void)cancelOperations;		// stop all work, will not get any more delegate calls after it returns
- (void)enumerateOperations:(void(^)(ConcurrentOperation *op))b;	// in some very special cases you may need this (I did)

@end

#if 0 

// 1) Add either a property or an ivar to the implementation file
OperationsRunner *operationsRunner;

// 2) Add the protocol to the class extension interface (often in the interface file)
@interface MyClass () <OperationsRunnerProtocol>

// 3) Add the header to the implementation file
#import "OperationsRunner.h"

// 4) Add this method to the implementation file (I put it at the bottom, could go into a category too)
- (id)forwardingTargetForSelector:(SEL)sel
{
	if(
		sel == @selector(runOperation:withMsg:)	|| 
		sel == @selector(runOperations:)		||
		sel == @selector(operationsCount)		||
		sel == @selector(enumerateOperations:)
	) {
		if(!operationsRunner) {
			// Object only created if needed
			operationsRunner = [[OperationsRunner alloc] initWithDelegate:self];
		}
		return operationsRunner;
	} else {
		return [super forwardingTargetForSelector:sel];
	}
}

// 5) Add the cancel to your dealloc (or the whole dealloc if you have none now)
- (void)dealloc
{
	[operationsRunner cancelOperations];	// you can send this at any time, for instance when the 'Back' button is tapped
}

// 6) Declare a category with these methods in the interface or implementation file (change MyClass to your class)
@interface MyClass (OperationsRunner)

- (void)runOperation:(ConcurrentOperation *)op withMsg:(NSString *)msg;	// to submit an operation
- (BOOL)runOperations:(NSSet *)operations;	// Set of ConcurrentOperation objects with their runMessage set (or not)

- (NSUInteger)operationsCount;	// uses dispatch_sync, so prefer to get the count in the delegate method

- (void)enumerateOperations:(void(^)(ConcurrentOperation *op))b;	// in some very special cases you may need this (I did)

@end

#endif
