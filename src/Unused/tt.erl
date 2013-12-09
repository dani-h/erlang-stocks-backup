-module(tt).

-compile(export_all).

-include_lib("xmerl/include/xmerl.hrl").

%% Can't send the Xml body to the values function

%% xml_url() ->
%%  inets:start(),
%%     {_, {_,_,Body}} = httpc:request("http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=AAPL"),
%%     { Xml, _Rest } = xmerl_scan:string(Body),
%%    %% io:format("~s~n", [Xml]),
%%      values(xmerl_xpath:string("//entry", Xml)). %% Makes sense??
%%     %%values(Xml).


%% The logic of the function seems correct to me, but can't extract any info

values([]) -> done;
values([Node|Rest]) ->
  [ #xmlText{value=Title} ] = xmerl_xpath:string("//title/text()", Node),
    io:format("~s~n", [Title]),
    io:format("~s~n", [Node]),
  [ #xmlAttribute{value=Link} ] = xmerl_xpath:string("//link/@href", Node),
  Message = xmerl:export_simple_content([{a,[{href,Link}],[Title]}],xmerl_xml),
  io:format('~s~n', [xmerl_ucs:to_utf8(Message)]),
  values(Rest).

%% I re-write the function to see if I will get different result, but I still   can't pattern match

get_feed() ->
    inets:start(),
  { ok, {_Status, _Headers, Body }} = httpc:request("http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=AAPL"),
  { Xml, _Rest } = xmerl_scan:string(Body),
    %% Trying to pattern match the title, but doesn't seem to work (unknown reason)
     [#xmlText{value = Title}] =  xmerl_xpath:string("//title/text()", Xml). 
    %%  io:format("~s~n", [Title]). 
    %% xmerl_xpath:string("//title/text()", Xml). %% It's showing the links in
                                                 %% list of tuples

    %% [#xmlText{parents=[{title,_}, {channel,_},_,_], value= title}]= xmerl_xpath:string("//title/text()",Xml),
    %% title.   %% NOT WORKING %%
