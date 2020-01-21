# frozen_string_literal: true

# Copyright Erisa A. (erisa.moe), Spotlight 2016-2020

module YuukiBot
  module Utility
    require 'rqrcode'

    YuukiBot.crb.add_command(
      :qr,
      code: proc { |event, args|
        content = args.join(' ')
        # "Sanitize" qr code content
        if content.length > 1000
          event.respond("#{YuukiBot.config['emoji_error']} " \
        'QR codes have a limit of 1000 characters. ' \
        "You went over by #{content.length - 1000}!")
          next
        end

        # Force the size to be 512x512 px.
        qr_code = RQRCode::QRCode.new(content)
        png = qr_code.as_png(size: 512)
        filename = 'qr.png'

        embed = Discordrb::Webhooks::Embed.new
        embed.colour = 0x74f167
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(
          name: "QR Code Generated by #{event.user.distinct}:",
          icon_url: Helper.avatar_url(event.user)
        )
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: 'Disclaimer: This QR Code is user-generated content.'
        )
        embed.add_field(name: 'QR Content:', value: "```#{content}```")

        # If we set attachment://qr.png as the resulting URL, the attached qr.png
        # will be used as the image, avoiding external image sources.
        embed.image = Discordrb::Webhooks::EmbedImage.new(
          url: "attachment://#{filename}"
        )

        upload_file_with_embed('', embed, png, filename, event.channel.id)
      },
      min_args: 1,
      catch_errors: true
    )

    # https://discordapp.com/developers/docs/resources/channel#create-message-using-attachments-within-embeds
    # @param [String (frozen)] contents The contents of the message being sent
    # @param [Object] embed The embed attached to this message
    # @param [Object] file The contents of the file itself.
    # @param [String (frozen)] The name of the file to present to Discord.
    # @param [String (frozen)] The ID of this channel to upload to.
    def self.upload_file_with_embed(contents = '', embed, file, filename, channel_id)
      # Create an IO stream for our payload information.
      payload = {
        content: contents,
        tts: false,
        embed: embed.to_hash,
        nonce: nil
      }.to_json

      # The default for to_blob is ASCII-8BIT, where we need UTF-8.
      file_datastream = file.to_datastream
      file_writer = StringIO.new
      file_writer.set_encoding('UTF-8')
      file_datastream.write(file_writer)

      # Route is POST /channels/{channel.id}/messages
      route = "#{Discordrb::API.api_base}/channels/#{channel_id}/messages"
      uri = URI.parse(route)

      form_req = Net::HTTP::Post.new(uri)
      form_req.set_form([
                          # It's mandatory to set a filename, otherwise the file
                          # fails to show up without warning.
                          ['file', file_writer.string, { filename: filename }],
                          ['payload_json', payload]
                        ], 'multipart/form-data')
      # Format: Authorization => Bot <token>
      form_req['Authorization'] = YuukiBot.crb.bot.token

      n = Net::HTTP.new(uri.host, uri.port)
      n.use_ssl = true
      n.start do |http|
        http.request(form_req)
      end
    end
  end
end
