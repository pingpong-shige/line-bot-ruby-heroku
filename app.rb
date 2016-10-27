require 'sinatra'
require 'line/bot'
require 'rest-client'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def get_user_local_bot_reply(word)
  response = RestClient.post 'https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue?APIKEY=4848502f6b39545568766a456237393879516f662f786c303742334a6f436e48676537512f7344514a3039', { params: { utt: CGI.escape(word) } }
  response_json = JSON.parse(response)
  response_json['utt'].present? ? response_json['utt'] : '通信エラー'
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: get_user_local_bot_reply(event.message['text'])
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

  "OK"
end
