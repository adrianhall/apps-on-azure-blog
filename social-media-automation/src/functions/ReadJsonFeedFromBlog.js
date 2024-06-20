const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');


const runningLocally = process.env.FUNCTIONS_CORETOOLS_ENVIRONMENT === "true";
const functionName = 'ReadJsonFeedFromBlog';
const schedule = '30 12 3 * * *';

const cosmosDbEndpoint = process.env.CosmosdbEndpoint;
const cosmosDatabaseName = process.env.DatabaseName;
const cosmosContainerName = process.env.ContainerName;

const credential = new DefaultAzureCredential();
const cosmosClient = new CosmosClient({
  endpoing: cosmosDbEndpoint,
  aadCredentials: credential
});
const cosmosContainer = cosmosClient.database(cosmosDatabaseName).container(cosmosContainerName);

const jsonFeedUrl = 'http://apps-on-azure.net/feed.json';

async function read_jsonfeed_from_blog(context) {
  context.verbose(`${functionName}>>> start: read_jsonfeed_from_blog`);
  try {
    context.verbose(`${functionName}>>> Reading JSON feed from ${jsonFeedUrl}`);
    const response = await fetch(jsonFeedUrl);
    context.verbose(`${functionName}>>> Converting JSON Feed to object.`);
    const data = await response.json();
    context.verbose(`${functionName}>>> Processing JSON feed items.`);
    for (let i = 0; i < data.items.length; i++) {
      const item = data.items[i];
      context.verbose(`${functionName}>>> Processing item: ${item.id}`);
      await writeBlogPostToCosmosDb(context, item);
    }
  } catch (error) {
    context.error(`Error fetching JSON feed from ${jsonFeedUrl}: ${JSON.stringify(error, '', 2)}`);
  }
  context.verbose(`${functionName}>>> end: read_jsonfeed_from_blog`);
  return {};
}

async function writeBlogPostToCosmosDb(context, blogPost) {
  context.verbose(`${functionName}>>> start: writeBlogPostToCosmosDb`);
  const response = await cosmosContainer.upsert(blogPost, { });
  context.verbose(`${functionName}>>> Blog post upserted to Cosmos DB: ${JSON.stringify(response, '', 2)}`);
  context.verbose(`${functionName}>>> end: writeBlogPostToCosmosDb`);
}

if (runningLocally) {
  app.http(functionName, {
    methods: [ 'GET' ],
    authLevel: 'anonymous',
    handler: async (request, context) => {
      context.verbose(`LOG>>> HTTP function "${functionName}" started`);
      const output = await read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> HTTP function "${functionName}" finished`);
      return { body: JSON.stringify(output) };
    }
  });
} else {
  app.timer(functionName, {
    schedule: '30 12 3 * * *',
    handler: async (timerInput, context) => {
      context.verbose(`LOG>>> Timer function "${functionName}" started`);
      const output = await read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> Timer function "${functionName}" finished`);
      return;
    }
  });
}



