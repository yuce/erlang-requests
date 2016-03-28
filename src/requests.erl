% Copyright (c) 2016, Yuce Tekol <yucetekol@gmail.com>.
% All rights reserved.

% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:

% * Redistributions of source code must retain the above copyright
%   notice, this list of conditions and the following disclaimer.

% * Redistributions in binary form must reproduce the above copyright
%   notice, this list of conditions and the following disclaimer in the
%   documentation and/or other materials provided with the distribution.

% * The names of its contributors may not be used to endorse or promote
%   products derived from this software without specific prior written
%   permission.

% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-module(requests).

-export([get/1,
         get/2,
         status_code/1,
         headers/1,
         headers/2,
         text/1]).

-define(REF(Response), {requests@response, Response}).
-define(VERSION, "0.1.0").

%% == API

get(Url) ->
    get(Url, #{}).

get(Url, Opts) ->
    NewOpts = process_opts(Opts),
    application:start(teacup),
    {ok, {Scheme, _Auth, Domain, Port, Path, Qry, _Fragment}} =
        http_uri:parse(Url, [{fragment, true}]),
    NewDomain = list_to_binary(Domain),
    Conn = case Scheme of
        http ->
            {ok, C} = teacup_http:connect(NewDomain, Port, NewOpts),
            C;
        https ->
            {ok, C} = teacup_http:connect(NewDomain, Port, NewOpts#{tls => true}),
            C
    end,
    NewPath = string:concat(Path, Qry),
    {ok, #{headers := Headers} = Response} =
        teacup_http:get_sync(Conn, list_to_binary(NewPath)),
    NewResponse = Response#{headers => maps:from_list(Headers)},
    teacup:disconnect(Conn),
    {ok, ?REF(NewResponse)}.

headers(?REF(#{headers := Headers})) -> Headers.
headers(?REF(#{headers := Headers}), HeaderName) ->
    maps:get(HeaderName, Headers, undefined).

text(?REF(#{body := Body})) -> Body.
status_code(?REF(#{status_code := StatusCode})) -> StatusCode.

%% == Internal

process_opts(Opts) ->
    Headers = maps:merge(default_headers(),
                         maps:get(headers, Opts, #{})),
    #{headers => Headers}.

default_headers() ->
    #{<<"user-agent">> => <<"erlang-requests/", ?VERSION>>}.

%% == Tests

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

get_1_test() ->
    {ok, R} = requests:get("https://httpbin.org/headers"),
    ?assertEqual(200, requests:status_code(R)),
    ?assertEqual(<<"application/json">>,
                 requests:headers(R, <<"content-type">>)),
    E = <<"{\n  \"headers\": {\n    \"Host\": \"httpbin.org\"\n  }\n}\n">>,
    ?assertEqual(E, requests:text(R)).

-endif.