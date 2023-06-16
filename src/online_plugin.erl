%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(online_plugin).

%% for #message{} record
%% no need for this include if we call emqx_message:to_map/1 to convert it to a map
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/emqx_hooks.hrl").


%% for logging
-include_lib("emqx/include/logger.hrl").

-export([ load/1
        , unload/0
        ]).

%% Client Lifecircle Hooks
-export([ on_client_connected/3]).

%% Called when the plugin application start
load(Env) ->
    hook('client.connected',    {?MODULE, on_client_connected, [Env]}),
    ok.

%%--------------------------------------------------------------------
%% Client LifeCircle Hooks
%%--------------------------------------------------------------------

on_client_connect(ConnInfo, Props, _Env) ->
    %% this is to demo the usage of EMQX's structured-logging macro
    %% * Recommended to always have a `msg` field,
    %% * Use underscore instead of space to help log indexers,
    %% * Try to use static fields
    ?SLOG(debug, #{msg => "demo_log_msg_on_client_connect",
                   conninfo => ConnInfo,
                   props => Props}),
    %% If you want to refuse this connection, you should return with:
    %% {stop, {error, ReasonCode}}
    %% the ReasonCode can be found in the emqx_reason_codes.erl
    {ok, Props}.

on_client_connack(ConnInfo = #{clientid := ClientId}, Rc, Props, _Env) ->
    io:format("Client(~s) connack, ConnInfo: ~p, Rc: ~p, Props: ~p~n",
              [ClientId, ConnInfo, Rc, Props]),
    {ok, Props}.

on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, _Env) ->
    io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
              [ClientId, ClientInfo, ConnInfo]).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, _Env) ->
  io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
              [ClientId, ReasonCode, ClientInfo, ConnInfo]).

on_client_authenticate(ClientInfo = #{clientid := ClientId}, Result, Env) ->
  io:format("Client(~s) authenticate, ClientInfo:~n~p~n, Result:~p,~nEnv:~p~n",
    [ClientId, ClientInfo, Result, Env]),
  {ok, Result}.

on_client_authorize(ClientInfo = #{clientid := ClientId}, PubSub, Topic, Result, Env) ->
  io:format("Client(~s) authorize, ClientInfo:~n~p~n, ~p to topic(~s) Result:~p,~nEnv:~p~n",
    [ClientId, ClientInfo, PubSub, Topic, Result, Env]),
  {ok, Result}.

on_client_subscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will subscribe: ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

on_client_unsubscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will unsubscribe ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

%%--------------------------------------------------------------------
%% Session LifeCircle Hooks
%%--------------------------------------------------------------------

on_session_created(#{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) created, Session Info:~n~p~n", [ClientId, SessInfo]).

on_session_subscribed(#{clientid := ClientId}, Topic, SubOpts, _Env) ->
    io:format("Session(~s) subscribed ~s with subopts: ~p~n", [ClientId, Topic, SubOpts]).

on_session_unsubscribed(#{clientid := ClientId}, Topic, Opts, _Env) ->
    io:format("Session(~s) unsubscribed ~s with opts: ~p~n", [ClientId, Topic, Opts]).

on_session_resumed(#{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) resumed, Session Info:~n~p~n", [ClientId, SessInfo]).

on_session_discarded(_ClientInfo = #{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) is discarded. Session Info: ~p~n", [ClientId, SessInfo]).

on_session_takenover(_ClientInfo = #{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) is takenover. Session Info: ~p~n", [ClientId, SessInfo]).

on_session_terminated(_ClientInfo = #{clientid := ClientId}, Reason, SessInfo, _Env) ->
    io:format("Session(~s) is terminated due to ~p~nSession Info: ~p~n",
              [ClientId, Reason, SessInfo]).

%%--------------------------------------------------------------------
%% Message PubSub Hooks
%%--------------------------------------------------------------------

%% Transform message and return
on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("Publish ~p~n", [emqx_message:to_map(Message)]),
    {ok, Message}.

on_message_dropped(#message{topic = <<"$SYS/", _/binary>>}, _By, _Reason, _Env) ->
    ok;
on_message_dropped(Message, _By = #{node := Node}, Reason, _Env) ->
    io:format("Message dropped by node ~p due to ~p:~n~p~n",
              [Node, Reason, emqx_message:to_map(Message)]).

on_message_delivered(_ClientInfo = #{clientid := ClientId}, Message, _Env) ->
    io:format("Message delivered to client(~s):~n~p~n",
              [ClientId, emqx_message:to_map(Message)]),
    {ok, Message}.

on_message_acked(_ClientInfo = #{clientid := ClientId}, Message, _Env) ->
    io:format("Message acked by client(~s):~n~p~n",
              [ClientId, emqx_message:to_map(Message)]).

%% Called when the plugin application stop
unload() ->
    unhook('client.connected',    {?MODULE, on_client_connected}).

hook(HookPoint, MFA) ->
    %% use highest hook priority so this module's callbacks
    %% are evaluated before the default hooks in EMQX
    emqx_hooks:add(HookPoint, MFA, _Property = ?HP_HIGHEST).

unhook(HookPoint, MFA) ->
    emqx_hooks:del(HookPoint, MFA).
