%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created : 27 Nov 2013 by  <Dungarov@DUNGAROV-PC>

-module(rss).

-compile(export_all).

-include_lib("xmerl/include/xmerl.hrl").
-include("../include/defs.hrl").

process_ticker(Ticker) ->
	inets:start(),
	{ok, {_Status, _Headers, Body}} = httpc:request("http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=" ++ string:to_upper(Ticker)),
    { Xml, _Rest } = xmerl_scan:string(Body),
    printItems(getElements(Xml), Ticker).

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
	{ok, Pid} = odbc:connect(?ConnectStr,[{timeout, 500000}]),
	_Result = odbc:sql_query(Pid, create_query(Item, Ticker)),
	% io:format("~p~n", [Result]),
	odbc:disconnect(Pid).
	% Q = create_query(Item, Ticker).
	% case length(Q) > 400 of
		% true -> io:format("~p~n", [Q]);
		% false -> ok
	% end.
	% &#39;

first(Item, Tag) ->
    hd([X || X <- Item#xmlElement.content,
         X#xmlElement.name == Tag]).

textOf(Item) ->
    lists:flatten([X#xmlText.value || X <- Item#xmlElement.content,
                      element(1,X) == xmlText]).
					  % &#39;
create_query(Item, Ticker)	->	 
Record = #news{date = format_date(textOf(first(Item, pubDate))), 
			  url = textOf(first(Item, link)),
			  headline = filter_headline(textOf(first(Item, title))),
			  ticker = Ticker}, 
% io:format("~p~n", [Record]),
gen_entry(news, Record) ++ ";".

filter_headline(Var) ->
	NewList = delete(Var, []),
	re:replace(NewList, "&#39;", "", [global, {return, list}]).
	
delete([H|T], Acc) when H > 127 ->
	% io:format("~p~n", [H]),
	delete(T, Acc);
delete([H|T], Acc) ->
	delete(T, Acc ++ [H]);
delete([], Acc) -> 
	Acc.
					  
format_date(Var) ->
	{A, _} = lists:split(16, Var),
	{{Y, M, D}, _} = ec_date:parse(A),
	Date = integer_to_list(Y) ++ "-"
			++ integer_to_list(M) ++ "-"
			++ integer_to_list(D),
	Date.
	
gen_entry(news,R) -> "EXEC s_addNews @Date='"++R#news.date++"',@Symbol='"++R#news.ticker++"',@Headline='"++R#news.headline++"',@Hyperlink='"++R#news.url++"'".