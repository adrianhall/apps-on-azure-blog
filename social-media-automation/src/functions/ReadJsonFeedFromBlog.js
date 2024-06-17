const { app } = require('@azure/functions');

app.timer('ReadJsonFeedFromBlog', {
    schedule: '3 12 * * * *',
    handler: (myTimer, context) => {
        context.log('Timer function processed request.');
    }
});
