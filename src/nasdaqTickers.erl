
-module(nasdaqTickers).
-export([getServer/1,get/0,filteredValues/3,deleteSymbols/1]).

getServer(Quary) ->
        {ok, {_,_,Body}} = httpc:request(Quary),
        {Body}.


get()-> 
        Data = getServer("http://www.nasdaq.com/screening/companies-by-name.aspx?&render=download"),

        [_|Values] = re:split(tuple_to_list(Data), ",\r\n|\n",[{return,list},{parts,2}]),
        
        CheckingForSpace = re:replace(Values,"\\\x20","",[global,{return,list}]),
        
        [H|T] = re:split(CheckingForSpace,"\\\x22,\r\n\\\x22|\\\x22,\\\x22|\\\x22,\r\n",[{return,list},trim]),
        
        filteredValues(T,[H],0).
        
        filteredValues([],Acc,_)->
        Value2 = deleteSymbols(Acc),
        Value2;
        
        filteredValues([H|T],Acc,Counter) when Counter == 8 ->
                filteredValues(T,[H]++Acc,0);
        filteredValues([_|T],Acc,Counter) ->
                filteredValues(T,Acc,Counter+1).

deleteSymbols([]) -> [];
deleteSymbols([H|T]) ->
        case (string:chr(H, $\") == 0) and (string:chr(H, $^) == 0) and (string:chr(H, $/) == 0) of %"
                false -> deleteSymbols(T);
                true -> [H|deleteSymbols(T)]
        end.