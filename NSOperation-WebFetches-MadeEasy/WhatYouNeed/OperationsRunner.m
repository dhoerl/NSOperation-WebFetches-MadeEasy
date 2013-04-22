//
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

#include <libkern/OSAtomic.h>

//extern void STLog(NSString *x, ...);
#define LOG NSLog

#import "OperationsRunner.h"

#import "ConcurrentOperation.h"

@interface OperationsRunner ()
@property (nonatomic, strong) NSOperationQueue			*queue;
@property (nonatomic, strong) NSMutableSet				*operations;
@property (nonatomic, assign) dispatch_queue_t			operationsQueue;
@property (atomic, weak) id <OperationsRunnerProtocol>	delegate;
@property (atomic, weak) id <OperationsRunnerProtocol>	savedDelegate;

@property (atomic, assign) double						threadPriority;
@property (atomic, assign) BOOL							cancelled;

@end

@implementation OperationsRunner
{
	long		_priority;							// the queue
	int32_t		_DO_NOT_ACCESS_operationsCount;		// named so as to discourage direct access
}
@dynamic priority;

- (id)initWithDelegate:(id <OperationsRunnerProtocol>)del
{
    if((self = [super init])) {
		_savedDelegate = _delegate = del;
		_queue		= [NSOperationQueue new];
		
		_operations	= [NSMutableSet setWithCapacity:10];
		_operationsQueue = dispatch_queue_create("com.dfh.operationsQueue", DISPATCH_QUEUE_SERIAL);
		
		_priority = 0;
		_threadPriority = -1;	// out of range, so don't set
	}
	return self;
}
- (void)dealloc
{
	[self cancelOperations];
	dispatch_release(_operationsQueue);
}

- (int32_t)adjustOperationsCount:(int32_t)val
{
	int32_t nVal = OSAtomicAdd32Barrier(val, &_DO_NOT_ACCESS_operationsCount);
	return nVal;
}

- (void)setDelegateThread:(NSThread *)delegateThread
{
	if(delegateThread != _delegateThread) {
		_delegateThread = delegateThread;
		_msgDelOn = msgOnSpecificThread;
	}
}

- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue
{
	if(delegateQueue != _delegateQueue) {
		_delegateQueue = delegateQueue;
		_msgDelOn = msgOnSpecificQueue;
	}
}

- (void)setPriority:(long)priority
{
	double tPriority;
	
	if(_priority != priority) {
		// keep this around while in development
		switch(priority) {
		case DISPATCH_QUEUE_PRIORITY_HIGH:
			tPriority = 0.75;
			break;
		case DISPATCH_QUEUE_PRIORITY_DEFAULT:
			tPriority = 0.5;
			break;
		case DISPATCH_QUEUE_PRIORITY_LOW:
			tPriority = 0.25;
			break;
		case DISPATCH_QUEUE_PRIORITY_BACKGROUND:
			tPriority = 0;
			break;
		default:
			assert(!"Invalid Priority Value");
			return;
		}
		_priority = priority;
				
		dispatch_set_target_queue(_operationsQueue, dispatch_get_global_queue(priority, 0));

		[[_queue operations] enumerateObjectsUsingBlock:^(ConcurrentOperation *op, NSUInteger idx, BOOL *stop)
			{
				if(![op threadPriority] == -1 && self.threadPriority == 0.5)  {
					[op setThreadPriority:self.threadPriority];
				}
			} ];
		self.threadPriority = tPriority;
		NSLog(@"tPriority=%f priority=%ld", tPriority, priority);
	}
}
- (long)priority
{
	return _priority;
}

- (NSUInteger)maxOps
{
	return _queue.maxConcurrentOperationCount;
}
- (void)setMaxOps:(NSUInteger)maxOps
{
NSLog(@"SET MAX %u", maxOps);
	_queue.maxConcurrentOperationCount = maxOps;
}

- (void)runOperation:(ConcurrentOperation *)op withMsg:(NSString *)msg
{
#ifndef NDEBUG
	if(self.cancelled) {
		assert([self adjustOperationsCount:0] == 0);
	}
#endif
	self.cancelled = NO;
	[self adjustOperationsCount:1];	// peg it even before its seen in the queue

	// Programming With ARC Release Notes pg 10 - non-trivial weak cases

#ifndef NDEBUG
	((ConcurrentOperation *)op).runMessage = msg;
#endif
	__weak __typeof__(self) weakSelf = self;
	dispatch_async(_operationsQueue, ^
		{
			[weakSelf _runOperation:op];
		} );
}

- (BOOL)runOperations:(NSSet *)ops
{
	int32_t count = (int32_t)[ops count];
	if(!count) {
		return NO;
	}

#ifndef NDEBUG
	if(self.cancelled) {
		assert([self adjustOperationsCount:0] == 0);
	}
#endif
	self.cancelled = NO;
	[self adjustOperationsCount:count];	// peg it even before its seen in the queue
	
	// Programming With ARC Release Notes pg 10 - non-trivial weak cases
	__weak __typeof__(self) weakSelf = self;
	dispatch_async(_operationsQueue, ^
		{
			[ops enumerateObjectsUsingBlock:^(ConcurrentOperation *op, BOOL *stop)
				{
					assert(weakSelf);
					[weakSelf _runOperation:op];
				} ];
				
		} );
	return YES;
}

- (void)_runOperation:(ConcurrentOperation *)op	// on queue
{
	if(self.cancelled) return;
	
#ifndef NDEBUG
	if(!self.noDebugMsgs) LOG(@"Run Operation: %@", op.runMessage);
#endif
	self.delegate = self.savedDelegate;

	__weak __typeof__(self) weakSelf2 = self;
	__weak __typeof__(op) weakOp = op;

	[op setCompletionBlock:^
		{
			__typeof__(self) strongSelf2 = weakSelf2;
			__typeof__(op) strongOp = weakOp;
			assert(strongSelf2 && strongOp);
			if(strongSelf2 && strongOp) {
				dispatch_async(strongSelf2.operationsQueue, ^
					{
						assert(strongOp);
						[strongSelf2 _operationFinished:strongOp];
					} );
			}
		} ];
		
	if(self.threadPriority >= 0) {
		[op setThreadPriority:self.threadPriority];
	}
	[_operations addObject:op];	// Second we retain and save a reference to the operation
	[_queue addOperation:op];	// Lastly, lets get going!
}

-(void)cancelOperations
{
	// LOG(@"OP cancelOperations");
	// if user waited for all data, the operation queue will be empty.
	self.delegate = nil;
	self.cancelled = YES;
	int32_t curval = [self adjustOperationsCount:0];
	[self adjustOperationsCount:-curval];
	assert([self adjustOperationsCount:0] == 0);

	dispatch_sync(_operationsQueue, ^	// has to be SYNC or you get crashes
		{
			[_operations removeAllObjects];
		} );

	[_queue cancelAllOperations];
	[_queue waitUntilAllOperationsAreFinished];
}

- (void)enumerateOperations:(void(^)(ConcurrentOperation *op))b
{
	//LOG(@"OP enumerateOperations");
	dispatch_sync(_operationsQueue, ^
		{
			[self.operations enumerateObjectsUsingBlock:^(ConcurrentOperation *operation, BOOL *stop)
				{
					b(operation);
				}];   
		} );
}

- (NSUInteger)operationsCount
{
	return [self adjustOperationsCount:0];
}

- (void)_operationFinished:(ConcurrentOperation *)op	// excutes in operationsQueue
{
	[_operations removeObject:op];
	int32_t nVal = [self adjustOperationsCount:-1];
	assert(nVal >= 0);
	assert(!(nVal == 0 && [_operations count]));	// if count == 0 better not have any operations in the queue
	// assert(!([_operations count] == 0 && nVal));	Since we bump the counter at the submisson point, not in queue, this could actually occurr

	// if you cancel the operation when its in the set, will hit this case
	if(op.isCancelled || self.cancelled) {
		// LOG(@"observeValueForKeyPath fired, but one of op.isCancelled=%d or self.isCancelled=%d", op.isCancelled, self.isCancelled);
		return;
	}

	//LOG(@"OP RUNNER GOT A MESSAGE %d for thread %@", _msgDelOn, delegateThread);	
	NSUInteger count = (NSUInteger)nVal;
	NSDictionary *dict;
	if(_msgDelOn !=  msgOnSpecificQueue) {
		dict = @{ @"op" : op, @"count" : @(count) };
	}

	switch(_msgDelOn) {
	case msgDelOnMainThread:
		[self performSelectorOnMainThread:@selector(operationFinished:) withObject:dict waitUntilDone:NO];
		break;

	case msgDelOnAnyThread:
		[self operationFinished:dict];
		break;
	
	case msgOnSpecificThread:
		[self performSelector:@selector(operationFinished:) onThread:_delegateThread withObject:dict waitUntilDone:NO];
		break;
		
	case msgOnSpecificQueue:
	{
		__weak id <OperationsRunnerProtocol> del = self.delegate;
		dispatch_async(_delegateQueue, ^
			{
				[del operationFinished:op count:count];
			} );
	}	break;
	}
}

- (void)operationFinished:(NSDictionary *)dict // excutes from multiple possible threads
{
	NSOperation *op		= dict[@"op"];
	NSUInteger count	= [(NSNumber *)dict[@"count"] unsignedIntegerValue];
	
	// Could have been queued on a thread and gotten cancelled. Once past this test the operation will be delivered
	if(op.isCancelled || self.cancelled) {
		return;
	}
	
	[self.delegate operationFinished:op count:count];
}

@end
