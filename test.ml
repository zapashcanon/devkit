
open OUnit
open Printf
open ExtLib

open Prelude

let tests = ref []
let test name f = let open OUnit in tests := (name >:: f) :: !tests

let test_search p s =
  let module WP = Web.Provider in
  let pr = print_endline in
(*   let url = sprintf "http://www.bing.com/search?q=%s&setmkt=fr-FR&go=&qs=n&sk=&sc=8-4&form=QBRE&filt=all" (Web.urlencode s) in *)
  let html = match s with
  | `Query s ->
      let url = p.WP.request s in
      printfn "url: %s" url;
(*       let (n,res,ads) = WP.bing_html (Std.input_file "search.html") in *)
      Web.http_get url
  | `File s ->
      Std.input_file s
  in
  let (n,res,ads) = p.WP.extract_full html in
  let summary = sprintf "results %d of %d and %d ads" (Array.length res) n (Array.length ads) in
  let show = Array.iter (fun (l,_,t,d) -> pr l; pr t; pr d; pr "") in
  pr summary;
  pr "RESULTS :";
  pr "";
  show res;
(*   pr summary; *)
  pr "ADS :";
  pr "";
  show ads;
  pr summary

let () = test "HtmlStream" begin fun () ->
  Printexc.record_backtrace true;
  let module HS = HtmlStream in
  let (==>) s s' = 
  try
    let s'' = Control.wrapped_output (IO.output_string ()) (fun io -> Stream.iter (IO.nwrite io $ HS.show_raw') (HS.parse (Stream.of_string s))) in
    if s' = s'' then () else
      failwith (sprintf "%s ==> %s (got %s)" s s' s'')
  with 
  | Failure s -> assert_failure s
  | exn -> assert_failure (sprintf "%s ==> %s (exn %s)\n%s" s s' (Exn.str exn) (Printexc.get_backtrace ())) 
  in
  "<q>dsds<qq>" ==> "<q>dsds<qq>";
  "<>" ==> "<>";
  "< q>" ==> "<>";
  "<q>" ==> "<q>";
  "<q><b>dsad</b></Q><Br/><a a a>" ==> "<q><b>dsad</b></q><br><a a='' a=''>";
  "<q x= a=2><q x a=2><q a=2/><q AAaa=2 />" ==> "<q x='a'><q x='' a='2'><q a='2'><q aaaa='2'>";
  "dAs<b a=\"d'dd\" b='q&q\"qq'></q a=2></><a'a>" ==> "dAs<b a='d'dd' b='q&q\"qq'></q></><a>";
  "dsad<v" ==> "dsad<v>";
  "dsa" ==> "dsa";
  "" ==> "";
  "<" ==> "<>";
  "<a q=>" ==> "<a q=''>";
  "<a q='>" ==> "<a q='>'>";
  "<a b='&amp;'>&amp;</a>" ==> "<a b='&amp;'>&amp;</a>";
  "<a b='&'>&</a>" ==> "<a b='&'>&</a>";
end

let () = test "iequal" begin fun () ->
  let t = let n = ref 0 in fun x -> assert_bool (sprintf "testcase %d" !n) x; incr n in
  let fail = t $ not in
  t (Stre.iequal "dSaDAS" "dsadas");
  t (Stre.iequal "dsadas" "dsadas");
  t (Stre.iequal "../@423~|" "../@423~|");
  t (Stre.iequal "" "");
  t (Stre.iequal "привет" "привет");
  t (Stre.iequal "hello" "HELLO");
  fail (Stre.iequal "hello" "hello!");
  fail (Stre.iequal "hello1" "hello!");
end

let () = test "Stre.iexists" begin fun () ->
  let f = Stre.iexists in
  let t = let n = ref 0 in fun x -> assert_bool (sprintf "testcase %d" !n) x; incr n in
  let fail = t $ not in
  t (f "xxxxdSaDAS" "dsadas");
  t (f "dSaDASxxxx" "dsadas");
  t (f "dSaDAS" "dsadas");
  t (f "xxxxdSaDASxxxx" "dsadas");
  t (f "xxxxdSaDAS" "DsAdAs");
  t (f "dSaDAS" "DsAdAs");
  t (f "xxxxdSaDASxxxx" "DsAdAs");
  t (f "dSaDASxxxx" "DsAdAs");
  t (f "xxxxdSaDAS" "");
  t (f "" "");
  t (f "12;dsaпривет" "привет");
  t (f "12;dsaпривет__324" "привет");
  fail (f "" "DsAdAs");
  fail (f "hello" "hellu");
  fail (f "hello" "hello!");
  fail (f "xxxxhello" "hello!");
  fail (f "helloxxx" "hello!");
  fail (f "hellox!helloXxx" "hello!");
  fail (f "" "x");
  fail (f "xyXZZx!x_" "xx");
end

let () = test "Cache.SizeLimited" begin fun () ->
  let module T = Cache.SizeLimited in
  let c = T.create 100 in
  let key = T.key in
  let test_get k = assert_equal ~printer:Std.dump (T.get c k) in
  let some k v = test_get (key k) (Some v) in
  let none k = test_get (key k) None in
  let iter f i1 i2 = for x = i1 to i2 do f x done in
  iter (fun i ->
    iter none i (1000+i);
    assert_equal (key i) (T.add c i);
    some i i) 0 99;
  iter (fun i ->
    iter none i (1000+i);
    iter (fun k -> some k k) (i-100) (i-1);
    assert_equal (key i) (T.add c i);
    some i i) 100 999;
  iter none 0 899;
  iter (fun k -> some k k) 900 999;
  iter none 1000 2000;
end

let () = test "Stre.by_words" begin fun () ->
  let t = let n = ref 0 in fun x -> assert_bool (sprintf "testcase %d" !n) x; incr n in
  let f a l = t (Stre.split Stre.by_words a = l) in
  f ("a" ^ String.make 10 '_' ^ "b") ["a"; "b"];
  f ("a" ^ String.make 1024 ' ' ^ "b") ["a"; "b"];
  f ("a" ^ String.make 10240 ' ' ^ "b") ["a"; "b"];
end

let () = test "ThreadPool" begin fun () ->
  let module TP = Parallel.ThreadPool in
  let pool = TP.create 3 in
  TP.wait_blocked pool;
  let i = ref 0 in
  for j = 1 to 10 do
    let worker _k () = incr i; Nix.sleep 0.2 in
    TP.put pool (worker j);
  done;
  TP.wait_blocked pool;
  assert_equal !i 10;
end

let () = test "Network.string_of_ipv4" begin fun () ->
  let t ip s =
    assert_equal ~printer:Int32.to_string ip (Network.ipv4_of_string_null s);
    assert_equal ~printer:id (Network.string_of_ipv4 ip) s
  in
  t 0l "0.0.0.0";
  t 1l "0.0.0.1";
  t 16777216l "1.0.0.0";
  t 2130706433l "127.0.0.1";
  t 16777343l "1.0.0.127";
  t 0xFFFFFFFFl "255.255.255.255";
  t 257l "0.0.1.1"
end

let () = test "Network.ipv4_matches" begin fun () ->
  let t ip mask ok =
    try
      assert_equal ok (Network.ipv4_matches (Network.ipv4_of_string_null ip) (Network.cidr_of_string_exn mask))
    with
      _ -> assert_failure (Printf.sprintf "%s %s %B" ip mask ok)
  in
  t "127.0.0.1" "127.0.0.0/8" true;
  t "127.0.1.1" "127.0.0.0/8" true;
  t "128.0.0.1" "127.0.0.0/8" false;
  t "192.168.0.1" "192.168.0.0/16" true;
  t "192.168.1.0" "192.168.0.0/16" true;
  t "192.169.0.1" "192.168.0.0/16" false;
  t "0.0.0.0" "0.0.0.0/8" true;
  t "0.123.45.67" "0.0.0.0/8" true;
  t "10.0.0.1" "0.0.0.0/8" false;
  t "172.16.0.1" "172.16.0.0/12" true;
  t "172.20.10.1" "172.16.0.0/12" true;
  t "172.30.0.1" "172.16.0.0/12" true;
  t "172.32.0.1" "172.16.0.0/12" false;
  t "172.15.0.1" "172.16.0.0/12" false;
  t "172.1.0.1" "172.16.0.0/12" false;
  t "255.255.255.255" "255.255.255.255/32" true;
  t "255.255.255.254" "255.255.255.255/32" false
end

let () = test "Web.extract_first_number" begin fun () ->
  let t n s =
    assert_equal ~printer:string_of_int n (Web.extract_first_number s);
  in
  t 10 "10";
  t 10 "00 10";
  t 10 "0010";
  t 10 "dsad10dsa";
  t 10 "10dsadsa";
  t 10 "10dadasd22";
  t 12345 "got 12,345 with 20 something";
  t 12345 "a1,2,3,4,5,,,6,7,8dasd";
  t 12345678 "a1,2,3,4,5,,6,7,8dasd";
  t 12345 "a,1,,2,,3,,4,,5,,,6,7,8dasd";
end

let () = test "Time.compact_duration" begin fun () ->
  let t n s =
    (* FIXME epsilon compare *)
    assert_equal ~printer:string_of_float n (Devkit_ragel.parse_compact_duration s);
  in
  let tt n s =
    t n s;
    assert_equal ~printer:id s (Time.compact_duration n);
  in
  tt 10. "10s";
  t 70. "70s";
  tt 70. "1m10s";
  t 10. "10";
  t 70. "70";
  t 70. "1m10";
  tt 7200. "2h";
  t 7200. "2h0s";
  t 7200. "1h60m";
  t 7200. "1h60m0s";
  t 7200. "7200s";
  t 7200. "1h3600s";
  t 7200. "1h0m3600s";
  t 7200. "1h30m1800s";
  t 7201. "90m1801s";
  t 7201.01 "90m1801.01s";
  t 7201.1 "90m1801.1s";
  t 7200.1 "2h0.1s";
  t 0.8 "0.8s";
(*   tt 0.8 "800ms"; *)
  tt 5356800. "62d";
end

let () = test "Action.partition" begin fun () ->
  let t l n =
    let open Action in
    assert_equal ~msg:(sprintf "partition %d" n) ~printer:(strl string_of_int) l (unpartition @@ partition l n)
  in
  t [1;2;3] 0;
  t [1;2;3] 1;
  t [] 0;
  t [] 1;
  for i = 1 to 10 do
    t (List.init (Random.int 10_000) id) (Random.int 100)
  done;
end

let () = test "Enum.align" begin fun () ->
  let e1 = List.enum [1;3;6;] in
  let e2 = List.enum [2;4;5;7;8;] in
  let l = List.of_enum & Enum.align compare e1 e2 in
  let expect = [1;2;3;4;5;6;7;8;] in
  OUnit.assert_equal ~printer:(Action.strl string_of_int) expect l
end

let () = test "Enum.group_assoc" begin fun () ->
  OUnit.assert_equal ~msg:"1"
    ["ds", 3; "dsa", 7; "ds", 11; ]
    (List.of_enum & Enum.group_assoc (=) (+) 0 & List.enum ["ds",1; "ds",2; "dsa",3; "dsa",4; "ds", 1; "ds", 10]);
  OUnit.assert_equal ~msg:"2"
    []
    (List.of_enum & Enum.group_assoc (=) (+) 0 & List.enum []);
end

let () = test "Enum.uniq" begin fun () ->
  OUnit.assert_equal ~msg:"1" ~printer:(Action.strl id)
    ["ds"; "dsa"; "ds"; ]
    (List.of_enum & Enum.uniq (=) & List.enum ["ds"; "ds"; "dsa"; "dsa"; "ds"; "ds"]);
  OUnit.assert_equal ~msg:"2"
    []
    (List.of_enum & Enum.uniq (=) & List.enum []);
  OUnit.assert_equal ~msg:"3" ~printer:(Action.strl string_of_int)
    [1;20;1;2;3;44]
    (List.of_enum & Enum.uniq (fun x y -> x mod 10 = y mod 10) & List.enum [1;11;20;100;0;1;2;3;133;44]);
  OUnit.assert_equal ~msg:"4" ~printer:Std.dump
    [(1, 1); (2, 2); (3, 1); (1, 4); (4, 1)]
    (List.of_enum @@ Enum.count_unique (=) @@ List.enum [1;2;2;3;1;1;1;1;4;]);
end

let () = test "Enum.iter_while" begin fun () ->
  let e = List.enum [1;2;3;4;5;6;7;] in
  Enum.iter_while (fun x -> if x = 2 then Enum.iter_while (fun x -> x < 6) e; x < 4) e;
  OUnit.assert_equal ~printer:(Action.strl string_of_int) [6;7] (List.of_enum e)
end

let tests () = 
  let (_:test_results) = run_test_tt_main ("devkit" >::: List.rev !tests) in
  ()

let () =
  let google = Web.Provider.(google {Google.hl="en"; gl="US"; tld="com"; lang="en";}) in
  match Action.args with
  | ["query";query] -> test_search google (`Query query)
  | ["file";file] -> test_search google (`File file)
  | ["http";port] -> Test_httpev.run (int_of_string port)
  | _ -> tests ()
