
NSOperation-WebFetches-MadeEasy

OperationsRunner does the heavy lifting
===============================

This project demonstrates the OperationsRunner ability to easily handle asynchronous web fetches (and really any application where you need the ability to message background task). The Core files are found in the WhatYouNeed folder, and the OperationsRunner.h file lists the handful of instructions to adopt it into any class you wish to use it in.

The demo app offers a few controls so that you can see for yourself that running operations can be cancelled and/or monitored.


UPDATES:

  2.0 (04/11/13) Improvements
    - switched from using keyValue observing of "isFinished" to the newer NSOperation's completionBlock, which simplified the code and reduced its size
    - added a queue property for users who want the delegate method to get dispatched asynchronously to that queue
    - refactored the 'operationFinished:' method in OperationsRunner so that the dispatch_sync could be made dispatch_async (for performance)
    - added the current remaining operation count to the delegate message, obviating the need for a dispatch_sync() callback that is almost always made in that method.
    - more comments in the OperationsRunner header file
    - Demo App updated to let you set Max Operations and Queue Priority (the DropBox was also out of date and needed updating)

  1.5 (01/05/13) Bug fix and new features:
    - 'cancelOperations' should have used 'dispatch_sync' instead of 'dispatch_async' - only discovered when using lots of operations on the background thread
    - can now set the maximum number of concurrent operations
    - can now make the target queue managing the operations use any valid dispatch queue (useful to make the UI more responsive when queuing thousands of operations)

  1.4 (12/11/12) Added a note that the cancel message should be sent to the operations runner in dealloc()

  1.3 (11/10/12) Made changes after discovering issues when this class is getting pressured:
    - Insure that operationCount is precise regardless of how many simultaneous delegate messages are queued at once
    - The 'cancelOperations' message must be sent to the object, to avoid actually creating an object in 'dealloc'

  1.2 (7/26/12): New option for OperationsRunner to allows messaging with delegate on a specific thread

  1.1 (7/12/12): broke WebFetcher into two classes, as the ConcurrentOperation class can more easily be re-used.

INTRO

This project is a simplified version of my Concurrent_NSOperations. That project fully explores just about everything you can do with Concurrent NSOperations, but because of this depth extracting just what you need to fetch data using asynchronous NSURLConnections is not all that clear.

Thus NSOperation-WebFetches-MadeEasy!

Most of the complexity involved in managing a pool of concurrent NSOperations is moved to a helper class, OperationsRunner. By adding two methods to one of your classes, using a few of its methods, and implementing one protocol method, you can get all the benefits of background web fetches with just a small amount of effort.

This project also supplies a NSOperation subclass, ConcurrentOperation, which deals with all the complexities of a concurrent NSOperation. One subclass of that is provided that is perfectly fine to use as is to download web content. You can also build on ConcurrentOperation to do other features like sequencers that need to run in their own thread.

DEMO

Run the enclosed project, which downloads three files from my DropBox Public folder concurrently.

USAGE

- add the OperationsRunner and ConcurrentOp to your project

- review the instructions in OperationsRunner.h, and add the various includes and methods as instructed

OPERATION

When you want to fetch some data, you create a new ConcurrentOp object, provide the URL of a resource (such as an image), and then message your class as:

    [myClass runOperation:op withMsg:@"Tracking string"];

The message parameter can take an arbitrary string or nil, however I strongly suggest you use a unique descriptive value. With debugging enabled, this string can get logged when the operation runs, when it completes, and the NSThread that runs the message is also tagged with it (did you know you can name NSThreads?)

When the operation completes, it messages your class on the main thread (unless you've configured it otherwise) as follows:

    [myClass operationFinished:(NSOperation *)op count:(NSUInteger)remainingCount];

Note that you don't even have to create the OperationsRunner - by using the NSObject method "forwardingTargetForSelector", the OperationsRunner gets created only when first messaged. This method also insures that the small set of messages destined for it get properly routed.

Suppose you need to cancel all operations, perhaps due to the user tapping the "Back" button. Simply message your class with:

    [operationsRunner cancelOperations]; // changed 11/10/12

You don't even need to do this! If you have active operations, when your class' dealloc is called, the OperationsRunner is also dealloced, and it properly tears down active operations.

The "operationFinished:count" method returns the remaining operation count, you can retire a spinner when it goes to zero. 
