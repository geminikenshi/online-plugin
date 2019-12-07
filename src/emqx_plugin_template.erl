%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_plugin_template).

-include_lib("emqx/include/emqx.hrl").

-export([ load/1
        , unload/0
        ]).

%% Hooks functions
-export([ on_client_authenticate/3
        , on_client_check_acl/5
        , on_client_connected/4
        , on_client_disconnected/4
        , on_client_subscribe/4
        , on_client_unsubscribe/4
        , on_session_resumed/3
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_message_publish/2
        , on_message_delivered/3
        , on_message_acked/3
        , on_message_dropped/3
        ]).

%% Called when the plugin application start
load(Env) ->
    emqx:hook('client.authenticate', fun ?MODULE:on_client_authenticate/3, [Env]),
    emqx:hook('client.check_acl', fun ?MODULE:on_client_check_acl/5, [Env]),
    emqx:hook('client.connected', fun ?MODULE:on_client_connected/4, [Env]),
    emqx:hook('client.disconnected', fun ?MODULE:on_client_disconnected/4, [Env]),
    emqx:hook('client.subscribe', fun ?MODULE:on_client_subscribe/4, [Env]),
    emqx:hook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/4, [Env]),
    emqx:hook('session.resumed', fun ?MODULE:on_session_resumed/3, [Env]),
    emqx:hook('session.subscribed', fun ?MODULE:on_session_subscribed/4, [Env]),
    emqx:hook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4, [Env]),
    emqx:hook('message.publish', fun ?MODULE:on_message_publish/2, [Env]),
    emqx:hook('message.delivered', fun ?MODULE:on_message_delivered/3, [Env]),
    emqx:hook('message.acked', fun ?MODULE:on_message_acked/3, [Env]),
    emqx:hook('message.dropped', fun ?MODULE:on_message_dropped/3, [Env]).

on_client_authenticate(ClientInfo = #{clientid := ClientId, password := Password}, AuthResult,_Env) ->
    io:format("Client(~s) authenticate, Password:~p ~n", [ClientId, Password]),
    {stop, AuthResult#{auth_result => success, anonymous => false}}.

on_client_check_acl(#{clientid := ClientId}, PubSub, Topic, DefaultACLResult, _Env) ->
    io:format("Client(~s) check_acl, PubSub:~p, Topic:~p, DefaultACLResult:~p~n",
              [ClientId, PubSub, Topic, DefaultACLResult]),
    {stop, allow}.

on_client_connected(#{clientid := ClientId}, ConnAck, _ConnInfo, _Env) ->
    io:format("Client(~s) connected, connack: ~w~n", [ClientId, ConnAck]).

on_client_disconnected(#{clientid := ClientId}, ReasonCode, _ConnInfo, _Env) ->
    io:format("Client(~s) disconnected, reason_code: ~w~n", [ClientId, ReasonCode]).

on_client_subscribe(#{clientid := ClientId}, _Properties, RawTopicFilters, _Env) ->
    io:format("Client(~s) will subscribe: ~p~n", [ClientId, RawTopicFilters]),
    {ok, RawTopicFilters}.

on_client_unsubscribe(#{clientid := ClientId}, _Properties, RawTopicFilters, _Env) ->
    io:format("Client(~s) unsubscribe ~p~n", [ClientId, RawTopicFilters]),
    {ok, RawTopicFilters}.

on_session_resumed(#{clientid := ClientId}, SessAttrs, _Env) ->
    io:format("Session(~s) resumed: ~p~n", [ClientId, SessAttrs]).

on_session_subscribed(#{clientid := ClientId}, Topic, SubOpts, _Env) ->
    io:format("Session(~s) subscribe ~s with subopts: ~p~n", [ClientId, Topic, SubOpts]).

on_session_unsubscribed(#{clientid := ClientId}, Topic, Opts, _Env) ->
    io:format("Session(~s) unsubscribe ~s with opts: ~p~n", [ClientId, Topic, Opts]).

%% Transform message and return
on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("Publish ~s~n", [emqx_message:format(Message)]),
    {ok, Message}.

on_message_delivered(#{clientid := ClientId}, Message, _Env) ->
    io:format("Deliver message to client(~s): ~s~n", [ClientId, emqx_message:format(Message)]),
    {ok, Message}.

on_message_acked(#{clientid := ClientId}, Message, _Env) ->
    io:format("Session(~s) acked message: ~s~n", [ClientId, emqx_message:format(Message)]),
    {ok, Message}.

on_message_dropped(_By, #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    ok;
on_message_dropped(#{node := Node}, Message, _Env) ->
    io:format("Message dropped by node ~s: ~s~n", [Node, emqx_message:format(Message)]);
on_message_dropped(#{clientid := ClientId}, Message, _Env) ->
    io:format("Message dropped by client ~s: ~s~n", [ClientId, emqx_message:format(Message)]).

%% Called when the plugin application stop
unload() ->
    emqx:unhook('client.authenticate', fun ?MODULE:on_client_authenticate/3),
    emqx:unhook('client.check_acl', fun ?MODULE:on_client_check_acl/5),
    emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
    emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/4),
    emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/4),
    emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/4),
    emqx:unhook('session.resumed', fun ?MODULE:on_session_resumed/3),
    emqx:unhook('session.subscribed', fun ?MODULE:on_session_subscribed/4),
    emqx:unhook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4),
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.delivered', fun ?MODULE:on_message_delivered/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3),
    emqx:unhook('message.dropped', fun ?MODULE:on_message_dropped/3).

