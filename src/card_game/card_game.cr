require "./chat_room"
require "./game_observer"
module CardGame
  class CardGame < Lattice::Connected::WebObject
    VALUES = %w(2 3 4 5 6 7 8 9 10 Jack Queen King Ace)
    SUITS  = %w(Hearts Diamonds Spades Clubs)
    property hand = [] of String
    property url : String?
    property deck : Array(String) = new_deck


    def content
      render "./src/card_game/card_game.slang"
    end

    def after_initialize
      (1..5).each {|c| hand << draw_card}
      add_child "chat_room", ChatRoom.child_of(creator: self)
      add_child "game_observer", GameObserver.child_of(creator: self)
      add_observer game_observer
      chat_room.add_observer game_observer
    end

    def game_observer
      @children["game_observer"].as(GameObserver)
    end

    def chat_room
      @children["chat_room"].as(ChatRoom)
    end

    def card_image(card)
      "/images/#{card.gsub(" ","_").downcase}.png"
    end

    def subscriber_action(data_item : String, action : Hash(String,JSON::Type), session_id : String, socket)
      begin
        player_name = Session.get(session_id).as(Session).string("name")  # we assume that this has been validated and a session exists and name is set
      rescue
        player_name = "Anon"
      end
      if action["action"]=="click" && (card = index_from(source: data_item, max: hand.size-1))
        hand[card] = draw_card
        update_attribute({"id"=>data_item, "attribute"=>"src", "value"=>card_image hand[card]})
        update({"id"=>"#{dom_id}-cards-remaining", "value"=>deck.size.to_s})
        chat_room.send_chat ChatMessage.build(chat_room, name: player_name, message: hand[card])
      end

    end

    def subscribed( session_id, socket)
      chat_room.subscribe(socket, session_id)  ##
      if (session = Session.get session_id) && (player_name = session.string?("name") )
        Storage.connection.exec "insert into player_game (player, game) values (?,?)", player_name, "#{name} (#{dom_id})"
      end
    end

    def draw_card
      self.deck = new_deck if self.deck.size == 0
      card = deck.sample
      deck.delete card
      card  # OPTIMIZE does delete already return this?
    end

    def new_deck : Array(String)
      VALUES.product(SUITS).map(&.join(" of ")) 
    end

  end
end
