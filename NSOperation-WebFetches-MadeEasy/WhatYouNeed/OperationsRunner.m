//
// NSOperation-WebFetches-MadeEasy (TM)
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

#define LOG NSLog

#import "OperationsRunner.h"

#import "WebFetcher.h"

@interface OperationsRunner ()
@property (nonatomic, strong) NSOperationQueue	*queue;
@property (nonatomic, strong) NSMutableSet		*operations;
@property (nonatomic, assign) dispatch_queue_t	operationsQueue;
@property (atomic, assign) BOOL					cancelled;

@end

@implementation OperationsRunner
{
	__weak id <OperationsRunnerProtocol>	delegate;
	long									_priority;
}
@dynamic priority;

- (id)initWithDelegate:(id <OperationsRunnerProtocol>)del
{
    if((self = [super init])) {
		delegate	= del;
		_queue		= [NSOperationQueue new];
		
		_operations	= [NSMutableSet setWithCapacity:10];
		_operationsQueue = dispatch_queue_create("com.dfh.operationsQueue", DISPATCH_QUEUE_SERIAL); //
	}
	return self;
}
- (void)dealloc
{
	[self cancelOperations];
	dispatch_release(_operationsQueue);
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
	if(_priority != priority) {
		// keep this around while in development
		switch(priority) {
		case DISPATCH_QUEUE_PRIORITY_HIGH:
		case DISPATCH_QUEUE_PRIORITY_DEFAULT:
		case DISPATCH_QUEUE_PRIORITY_LOW:
		case DISPATCH_QUEUE_PRIORITY_BACKGROUND:
			_priority = priority;
			break;
		default:
			assert(!"Invalid Priority Value");
			return;
		}
		
		dispatch_set_target_queue(_operationsQueue, dispatch_get_global_queue(_priority, 0));
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
	_queue.maxConcurrentOperationCount = maxOps;
}

- (void)runOperation:(NSOperation *)op withMsg:(NSString *)msg
{
	self.cancelled = NO;

	__weak __typeof__(self) weakSelf = self;
	dispatch_async(_operationsQueue, ^
		{
			// Programming With ARC Release Notes pg 10 - non-trivial weak cases
			__typeof__(self) strongSelf = weakSelf;

			if(!strongSelf || strongSelf.cancelled) return;
#ifndef NDEBUG
			if(!_noDebugMsgs) LOG(@"Run Operation: %@", msg);
			if([op isKindOfClass:[WebFetcher class]]) {
				WebFetcher *fetcher = (WebFetcher *)op;
				fetcher.runMessage = msg;
			}
#endif
			__weak __typeof__(self) weakSelf2 = strongSelf;	// kch
			__weak __typeof__(op) weakOp = op;	// kch
			[op setCompletionBlock:^
				{
					__typeof__(self) strongSelf2 = weakSelf2;
					if(strongSelf2) {
						dispatch_async(strongSelf2.operationsQueue, ^
							{
								[strongSelf2 _operationFinished:weakOp];
							} );
					}
				} ];
				
			[strongSelf.operations addObject:op];	// Second we retain and save a reference to the operation
			[strongSelf.queue addOperation:op];	// Lastly, lets get going!
		} );
}

-(void)cancelOperations
{
	//LOG(@"OP cancelOperations");
	// if user waited for all data, the operation queue will be empty.
	self.cancelled = YES;

	dispatch_sync(_operationsQueue, ^	// MUST BE SYNC
		{
			[self.operations removeAllObjects];
		} );

	[_queue cancelAllOperations];
	[_queue waitUntilAllOperationsAreFinished];
}

- (void)enumerateOperations:(void(^)(NSOperation *op))b
{
	//LOG(@"OP enumerateOperations");
	dispatch_sync(_operationsQueue, ^
		{
			[self.operations enumerateObjectsUsingBlock:^(NSOperation *operation, BOOL *stop)
				{
					b(operation);
				}];   
		} );
}

- (NSSet *)operationsSet
{
	__block NSSet *set;
	dispatch_sync(_operationsQueue, ^
		{
            set = [NSSet setWithSet:self.operations];
        } );
	return set;
}

- (NSUInteger)operationsCount
{
	__block NSUInteger count;
	dispatch_sync(_operationsQueue, ^
		{
            count = [_operations count];
        } );
	return count;
}

- (void)_operationFinished:(NSOperation *)op	// excutes in operationsQueue
{
	if([_operations containsObject:op]) {
		[_operations removeObject:op];

		// if you cancel the operation when its in the set, will hit this case
		if(op.isCancelled || self.cancelled) {
			// LOG(@"observeValueForKeyPath fired, but one of op.isCancelled=%d or self.isCancelled=%d", op.isCancelled, self.isCancelled);
			return;
		}
	} else {
		// LOG(@"observeValueForKeyPath fired, but not in set");
		return;
	}

	//LOG(@"OP RUNNER GOT A MESSAGE %d for thread %@", _msgDelOn, delegateThread);

	NSUInteger count = [_operations count];
	NSDictionary *dict = @{ @"op" : op, @"count" : @(count) };

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
		dispatch_async(_delegateQueue, ^
			{
				[delegate operationFinished:op count:count];
			} );
		break;
	}
}

- (void)operationFinished:(NSDictionary *)dict
{
	NSOperation *op		= dict[@"op"];
	NSUInteger count	= [(NSNumber *)dict[@"count"] unsignedIntegerValue];
	
	// Could have been queued on a thread and gotten cancelled. Once past this test the operation will be delivered
	if(op.isCancelled || self.cancelled) {
		return;
	}
	
	[delegate operationFinished:op count:count];
}

@end
