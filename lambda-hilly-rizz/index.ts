import { Context, APIGatewayProxyResult, APIGatewayEvent } from 'aws-lambda';
import { Configuration, OpenAIApi } from 'openai';
import Twilio from 'twilio';

export const handler = async (
  event: APIGatewayEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  const configuration = new Configuration({
    apiKey: process.env.OPENAI_API_KEY,
  });

  const openai = new OpenAIApi(configuration);
  const response = await openai.createCompletion({
    model: 'text-davinci-003',
    prompt: 'Give a quote to rizz up my girlfriend',
    temperature: 0.5,
    max_tokens: 100,
  });

  const ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
  const AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;

  const client = Twilio(ACCOUNT_SID, AUTH_TOKEN);

  await client.messages
    .create({
      body: response.data.choices[0].text,
      from: process.env.TWILIO_FROM_PHONE_NUMBER,
      to: process.env.TWILIO_TO_PHONE_NUMBER_ONE ?? '',
    })
    .then((message) => {
      console.log(message.sid);
    });

  await client.messages
    .create({
      body: response.data.choices[0].text,
      from: process.env.TWILIO_FROM_PHONE_NUMBER,
      to: process.env.TWILIO_TO_PHONE_NUMBER_TWO ?? '',
    })
    .then((message) => {
      console.log(message.sid);
    })

    .catch((e) => console.log(e.message));

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'hello world',
    }),
  };
};
