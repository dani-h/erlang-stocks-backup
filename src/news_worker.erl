%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created : 27 Nov 2013 by  <Dungarov@DUNGAROV-PC>

-module(news_worker).
-compile(export_all).
-include_lib("xmerl/include/xmerl.hrl").
-include("../include/defs.hrl").


process_ticker(Ticker, Restarts) ->
%% 	io:format("Pid: ~p, Processing Ticker:~p~n", [self(), Ticker]),
	try
		{ok, {_Status, _Headers, Body}} = httpc:request(
			"http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=" 
				++ string:to_upper(Ticker)),
		{ Xml, _Rest } = xmerl_scan:string(Body),
		printItems(getElements(Xml), Ticker),
		exit({normal, Ticker})
	catch
		error:{badmatch,{error,socket_closed_remotely}} -> 
%% 			io:format("Socket closed remotely, ticker: ~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts});
		error:{badmatch, {error, {failed_connect,_}}} ->
%% 			io:format("Failed connect, ticker: ~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts});
		error:{badmatch,{error,timeout}} ->
%% 			io:format("Timed out, ticker:~p~n", [Ticker]),
			exit({badmatch, Ticker, Restarts});
		error:Catch_all -> 
			io:format("~nIn ex, catch_all, Msg: ~p~n", [Catch_all]),
			exit({catch_all, Catch_all})
	end.

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
	printItems(Items, [], Ticker).

printItems([H|T], Acc, Ticker) ->
	printItems(T, [create_query(H, Ticker)|Acc], Ticker);
printItems([], Acc, _Ticker) -> 
	ok.
%% 	io:format("~p~n", [Acc]).
%% 	{ok, Pid} = odbc:connect(?ConnectStr,[{timeout, 2000}]),
%% 	_Result = odbc:sql_query(Pid, Acc),
%% 	odbc:disconnect(Pid).

first(Item, Tag) ->
	hd([X || X <- Item#xmlElement.content,
			 X#xmlElement.name == Tag]).

textOf(Item) ->
	lists:flatten([X#xmlText.value || X <- Item#xmlElement.content,
									  element(1,X) == xmlText]).

create_query(Item, Ticker)	->	 
	Record = #news{date = format_date(textOf(first(Item, pubDate))), 
				   url = textOf(first(Item, link)),
				   headline = filter_headline(textOf(first(Item, title))),
				   ticker = Ticker}, 
	gen_entry(news, Record) ++ ";".

filter_headline(Var) ->
	NewList = delete(Var, []),
	re:replace(NewList, "&#39;", "", [global, {return, list}]).

delete([H|T], Acc) when H > 127 ->
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

% Code below by Robert Petre
gen_entry(news,R) -> "EXEC s_addNews @Date='"++R#news.date++"',@Symbol='"++R#news.ticker++"',@Headline='"++R#news.headline++"',@Hyperlink='"++R#news.url++"'".