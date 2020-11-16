public inherited sharing class SafetyQueueRunner {

    private static final Integer SECONDS_TO_CONTINUE = 2;

    @TestVisible
    private static Set<Queueable> queuesToProcessLater = new Set<Queueable>();
    private static Boolean isMaximumDeepsExceeded = false;
    private static String scheduleId;

    public static Boolean enqueueJobIfPossible(Queueable queueable) {
        return enqueueAndRemoveFromExecutionIfPossible(queuesToProcessLater, queueable);
    }

    public static Boolean canBeQueuedNow() {
        return Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !isMaximumDeepsExceeded;
    }

    public static void enqueueJobIfPossibleOrAddForLaterProcessing(Queueable queueable) {
        enqueueJobIfPossibleOrAddForLaterProcessing(queuesToProcessLater, queueable);
    }

    public static void addQueueForLaterProcessing(Queueable queueable) {
        addQueueForLaterProcessing(queuesToProcessLater, queueable);
    }

    public static void processRestJobs() {
        processRestJobs(queuesToProcessLater, true);
    }

    public static void scheduleProcessingRestJobs() {
        processRestJobs(queuesToProcessLater, false);
    }

    public static void clearRestJobs() {
        clearRestJobs(queuesToProcessLater);
    }

    private static void processRestJobs(Set<Queueable> queuesToProcess, Boolean shouldTryProcessNow) {
        if (shouldTryProcessNow) {
            for (Queueable queueable : queuesToProcess) {
                if (!canBeQueuedNow()) break;

                enqueueAndRemoveFromExecutionIfPossible(queuesToProcess, queueable);
            }
        }

        enqueueScheduledJobsIfExist(queuesToProcess);
    }

    private static void enqueueJobIfPossibleOrAddForLaterProcessing(Set<Queueable> queuesToProcess, Queueable queueable) {
        if (!enqueueAndRemoveFromExecutionIfPossible(queuesToProcess, queueable)) {
            addQueueForLaterProcessing(queuesToProcess, queueable);
        }
    }

    private static Boolean enqueueAndRemoveFromExecutionIfPossible(Set<Queueable> queuesToProcess, Queueable queueable) {
        if (canBeQueuedNow()) {
            try {
                System.enqueueJob(queueable);
                removeProcessedQueue(queuesToProcess, queueable);
                return true;
            } catch (AsyncException e) {
                isMaximumDeepsExceeded = true;
                System.debug('Maximum deeps is exceeded');
            }
        }
        System.debug('You can\'t enqueueJob now');
        return false;
    }

    private static void addQueueForLaterProcessing(Set<Queueable> queuesToProcess, Queueable queueable) {
        queuesToProcess.add(queueable);
    }

    private static void removeProcessedQueue(Set<Queueable> queuesToProcess, Queueable queueable) {
        queuesToProcess.remove(queueable);
    }

    private static void enqueueScheduledJobsIfExist(Set<Queueable> queuesToProcess) {
        System.debug(queuesToProcess);
        if (queuesToProcess.size() == 0) return;

        String cron = Datetime.now().addSeconds(SECONDS_TO_CONTINUE).format('s m * * * ?');
        scheduleId = System.schedule('Process queues ' + Datetime.now().getTime(), cron, new SafetyQueueRunnerSchedulable(queuesToProcess));
        System.debug(scheduleId);
        clearRestJobs(queuesToProcess);
    }

    private static void clearRestJobs(Set<Queueable> queuesToProcess) {
        queuesToProcess.clear();
    }

    private static void abortSchedule(Id scheduleId) {
        if (String.isNotEmpty(scheduleId)) System.abortJob(scheduleId);
    }

    @TestVisible
    private class SafetyQueueRunnerSchedulable implements Schedulable {

        private Set<Queueable> queuesToProcess = new Set<Queueable>();

        @TestVisible
        private SafetyQueueRunnerSchedulable(Set<Queueable> queuesToProcess) {
            this.queuesToProcess = queuesToProcess;
        }

        public void execute(SchedulableContext sc) {
            abortSchedule(sc != null ? sc.getTriggerId() : null);
            this.processRestJobs();
        }

        private void processRestJobs() {
            SafetyQueueRunner.processRestJobs(this.queuesToProcess, true);
        }
    }
}