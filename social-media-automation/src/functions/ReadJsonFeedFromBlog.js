const { app } = require('@azure/functions');

const runningLocally = process.env.FUNCTIONS_CORETOOLS_ENVIRONMENT === "true";
const functionName = 'ReadJsonFeedFromBlog';
const schedule = '30 12 3 * * *';

function read_jsonfeed_from_blog(context) {
  context.verbose(`${functionName}>>> start: read_jsonfeed_from_blog`);

  context.verbose(`${functionName}>>> end: read_jsonfeed_from_blog`);
  return {};
}

if (runningLocally) {
  app.http(functionName, {
    methods: [ 'GET' ],
    authLevel: 'anonymous',
    handler: async (request, context) => {
      context.verbose(`LOG>>> HTTP function "${functionName}" started`);
      const output = read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> HTTP function "${functionName}" finished`);
      return { body: JSON.stringify(output) };
    }
  });
} else {
  app.timer(functionName, {
    schedule: '30 12 3 * * *',
    handler: (timerInput, context) => {
      context.verbose(`LOG>>> Timer function "${functionName}" started`);
      const output = read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> Timer function "${functionName}" finished`);
      return;
    }
  });
}



