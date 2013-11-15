%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created :  6 Nov 2013 by  <Dungarov@DUNGAROV-PC>

-module(xmlp).

-export([scan/0]).
-include_lib("xmerl/include/xmerl.hrl").

xml_url() ->
  "http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=AAPL".

scan() ->
  application:start(inets),
  { ok, {_Status, _Headers, Body }} = httpc:request(xml_url()),
  { Xml, _Rest } = xmerl_scan:string(Body),
   %% io:format("~s~n", [Body]),
  values(xmerl_xpath:string("//entry",Xml)),
    io:format("~s~n", [Xml]),
  init:stop().

values([]) -> done;
values([Node|Rest]) ->
  [ #xmlText{value=Title} ] = xmerl_xpath:string("title/text()", Node),
    io:format("~s~n", [Title]),
    io:format("~s~n", [Node]),
  [ #xmlAttribute{value=Link} ] = xmerl_xpath:string("link/@href", Node),
  Message = xmerl:export_simple_content([{a,[{href,Link}],[Title]}],xmerl_xml),
  io:format('~s~n', [xmerl_ucs:to_utf8(Message)]),
  values(Rest).
