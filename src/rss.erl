%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created : 27 Nov 2013 by  <Dungarov@DUNGAROV-PC>

-module(rss).

-compile(export_all).

-include_lib("xmerl/include/xmerl.hrl").
-record(news, {date = "", ticker = "", headline = "", url = ""}).

g() ->
	inets:start(),
	{ok, {_Status, _Headers, Body}} = httpc:request("http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=AAPL"),
    { Xml, _Rest } = xmerl_scan:string(Body),
    printItems(getElements(Xml), aapl).

getElements([H|T]) when H#xmlElement.name == item ->
    [H | getElements(T)];
getElements([H|T]) when is_record(H, xmlElement) ->
    getElements(H#xmlElement.content) ++
      getElements(T);                                                                 
getElements(X) when is_record(X, xmlElement) ->
    getElements(X#xmlElement.content);
getElements([_|T]) ->
    getElements(T);
getElements([]) ->
    [].

printItems(Items, Ticker) ->
    F = fun(Item) -> printItem(Item, Ticker) end,
    lists:foreach(F, Items).
 
printItem(Item, Ticker) ->
%%     io:format("title: ~s~n", [textOf(first(Item, title))]),
%%     io:format("link: ~s~n", [textOf(first(Item, link))]),
%%     io:format("description: ~s~n", [textOf(first(Item, pubDate))]),
	R = #news{date = textOf(first(Item, pubDate)), 
			  url = textOf(first(Item, link)),
			  headline = textOf(first(Item, title)),
			  ticker = Ticker},
	io:format("~p~n", [R]).



first(Item, Tag) ->
    hd([X || X <- Item#xmlElement.content,
         X#xmlElement.name == Tag]).

textOf(Item) ->
    lists:flatten([X#xmlText.value || X <- Item#xmlElement.content,
                      element(1,X) == xmlText]).
