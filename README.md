NSOperation-WebFetches-MadeEasy
===============================

UPDATES:
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

    [myClass runOperation:op withMsg:@"Some string"];

The message parameter can take an arbitrary string or nil, however I strongly suggest you use a unique descriptive value. With debugging enabled, this string can get logged when the operation runs, when it completes, and the NSThread that runs the message is also tagged with it (did you know you can name NSThreads?)

When the operation completes, it messages your class on the main thread (unless you've configured it otherwise) as follows:

    [myClass operationFinished:(NSOperation *)op];

Note that you don't even have to create the OperationsRunner - by using the NSObject method "forwardingTargetForSelector", the OperationsRunner gets created only when first messaged. This method also insures that the small set of messages destined for it get properly routed.

Suppose you need to cancel all operations, perhaps due to the user tapping the "Back" button. Simply message your class with:

    [operationsRunner cancelOperations]; // changed 11/10/12

You don't even need to do this! If you have active operations, when your class' dealloc is called, the OperationsRunner is also dealloced, and it properly tears down active operations.

A useful convenience method, "-(NSUInteger)operationsCount", returns the current queue count. When used within "operationFinished:", you can retire a spinner when it goes to zero.  