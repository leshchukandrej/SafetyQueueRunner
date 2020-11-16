@IsTest
public with sharing class SafetyQueueRunnerTest {

    static final Integer BULK_QUEUE_SIZE = 201;

    static Boolean isSuccess = true;

    private static final String ACCOUNT_NAME = 'TestAccount';

    @IsTest static void enqueueJobDeepTestSuccess() {
        assertDeepQueueExecution(true);
    }

    @IsTest static void enqueueJobDeepTestFailed() {
        assertDeepQueueExecution(false);
    }

    @IsTest static void enqueueJobIfPossible() {
        Test.startTest();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            SafetyQueueRunner.enqueueJobIfPossible(new BulkQueueForTest(i));
        }

        Test.stopTest();

        System.assertEquals(0, SafetyQueueRunner.queuesToProcessLater.size());
        System.assertEquals(Limits.getLimitQueueableJobs(), getProcessedRecords());
    }

    @IsTest static void enqueueJobIfPossibleOrAddForLaterProcessing() {
        Test.startTest();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            SafetyQueueRunner.enqueueJobIfPossibleOrAddForLaterProcessing(new BulkQueueForTest(i));
        }

        Test.stopTest();

        System.assertEquals(BULK_QUEUE_SIZE - Limits.getLimitQueueableJobs(), SafetyQueueRunner.queuesToProcessLater.size());
        System.assertEquals(Limits.getLimitQueueableJobs(), getProcessedRecords());
    }

    @IsTest static void processRestJobs() {
        Test.startTest();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            SafetyQueueRunner.addQueueForLaterProcessing(new BulkQueueForTest(i));
        }

        SafetyQueueRunner.processRestJobs();

        Test.stopTest();

        System.assert(isQueuesScheduled());
        System.assertEquals(Limits.getLimitQueueableJobs(), getProcessedRecords());
    }

    @IsTest static void scheduleProcessingRestJobs() {
        Test.startTest();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            SafetyQueueRunner.addQueueForLaterProcessing(new BulkQueueForTest(i));
        }

        SafetyQueueRunner.scheduleProcessingRestJobs();

        Test.stopTest();

        System.assert(isQueuesScheduled());
        System.assertEquals(0, getProcessedRecords());
    }

    @IsTest static void clearRestJobs() {
        Test.startTest();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            SafetyQueueRunner.addQueueForLaterProcessing(new BulkQueueForTest(i));
        }

        Test.stopTest();

        System.assertEquals(BULK_QUEUE_SIZE, SafetyQueueRunner.queuesToProcessLater.size());

        SafetyQueueRunner.clearRestJobs();

        System.assertEquals(0, SafetyQueueRunner.queuesToProcessLater.size());

        System.assertEquals(0, getProcessedRecords());
    }

    @IsTest static void enqueueJobSafetyBulkFromSchedule() {
        Set<Queueable> queues = new Set<Queueable>();

        for (Integer i = 0; i < BULK_QUEUE_SIZE; i++) {
            queues.add(new BulkQueueForTest(i));
        }

        Test.startTest();

        SafetyQueueRunner.SafetyQueueRunnerSchedulable safetyQueueRunnerSchedulable = new SafetyQueueRunner.SafetyQueueRunnerSchedulable(queues);

        safetyQueueRunnerSchedulable.execute(null);

        Test.stopTest();

        System.assert(isQueuesScheduled());
        System.assertEquals(Limits.getLimitQueueableJobs(), getProcessedRecords());
    }

    static void assertDeepQueueExecution(Boolean isSafety) {
        Test.startTest();

        System.enqueueJob(new DeepQueueForTests(2).setIsSafety(isSafety));

        Test.stopTest();

        System.assertEquals(isSafety, isSuccess);
        System.assertEquals(isSafety, isQueuesScheduled());
        System.assertEquals(1, getProcessedRecords());
    }

    static Boolean isQueuesScheduled() {
        return [SELECT COUNT() FROM CronTrigger] > 0;
    }

    static Integer getProcessedRecords() {
        return [SELECT COUNT() FROM Account];
    }

    class DeepQueueForTests implements Queueable {

        private Integer maxDeepness;
        private Integer deepness = 1;

        private Boolean isSafety = false;

        public DeepQueueForTests(Integer maxDeepness) {
            this.maxDeepness = maxDeepness;
        }

        public DeepQueueForTests setIsSafety(Boolean isSafety) {
            this.isSafety = isSafety;
            return this;
        }

        public void execute(QueueableContext qc) {
            insert new Account(Name = ACCOUNT_NAME + this.deepness);

            if (++this.deepness > this.maxDeepness) return;

            if (this.isSafety) {
                SafetyQueueRunner.enqueueJobIfPossibleOrAddForLaterProcessing(this);
                SafetyQueueRunner.processRestJobs();
            } else {
                try {
                    System.enqueueJob(this);
                } catch (AsyncException e) {
                    isSuccess = false;
                }
            }
        }
    }

    class BulkQueueForTest implements Queueable {
        Integer queueNumber;

        public BulkQueueForTest(Integer queueNumber) {
            this.queueNumber = queueNumber;
        }

        public void execute(QueueableContext qc) {
            insert new Account(Name = ACCOUNT_NAME + this.queueNumber);
        }
    }
}