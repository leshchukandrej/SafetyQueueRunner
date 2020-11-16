# SafetyQueueRunner
This class is used for controlling queue execution. In case if you want to enqueue job later or in case you want to enqueue it safely, use this class.

Samples of using this class contains in SafetyQueueRunnerTest class.

`enqueueJobIfPossible(Queueable queueable)` tries to enqueue job if it is allowed and returns result of enqueument - success or not;

`canBeQueuedNow()` returns true if it is allowed to enqueue job now;

`enqueueJobIfPossibleOrAddForLaterProcessing(Queueable queueable)` tries to enqueue job, if it's not allowed, addes to list for scheduled execution;

`addQueueForLaterProcessing(Queueable queueable)` adds queue to list for scheduled execution;

`processRestJobs()` tries to enqueue all added to list for schedule execution jobs, if it's not allowed for any, it schedules excecution of them later;

`scheduleProcessingRestJobs()` schedules excecution of previously added to a list queues;

`clearRestJobs()` clear list of previously added queues.

If it's possible it's better to use `processRestJobs()` or `scheduleProcessingRestJobs()` as later as possible to make it bulkify and not to stuck in limits of scheduling (**100 schedules per transaction**).
