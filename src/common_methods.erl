-module(common_methods).
-compile(export_all).


read_existing_file() ->
	case filelib:is_file("tickers.txt") of
		true ->
			{ok, Binary} = file:read_file("tickers.txt"),
			parse_binary(binary_to_list(Binary));
		false ->
			throw("Tickers.txt not found")
	end.
parse_binary(Binary) ->
	String = re:replace(Binary, "\\[|]|'|\\s|\\n| |\\.|", "", [global, {return, list}]),
	List = string:tokens(String, ","),
	List.

print(Module, Msg) ->
	case Module of
		hist_gen ->
			io:format("[Historical] - ");
		hist_worker ->
			io:format("[Historical] - ");
		news_gen ->
			io:format("[News] - ");
		news_worker ->
			io:format("[News] - ");
		nasdaqTickers ->
			io:format("[Nasdaq] - ");
		nasdaq_bridge ->
			io:format("[Nasdaq] - ")
	end,
	io:format("~s~n", [Msg]).

print(Module, Msg, Param) ->
	case Module of
		hist_gen ->
			io:format("[Historical] - ");
		hist_worker ->
			io:format("[Historical] - ");
		news_gen ->
			io:format("[News] - ");
		news_worker ->
			io:format("[News] - ");
		nasdaqTickers ->
			io:format("[Nasdaq] - ");
		nasdaq_bridge ->
			io:format("[Nasdaq] - ")
	end,
	io:format("~s ~p~n", [Msg, Param]).