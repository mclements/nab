(*                                  *)
(* mws  multihop wireless simulator *)
(*                                  *)

open Printf
open Misc
open Script_utils

let daemon = false
let outfile = ref (Unix.getcwd())
let outfile_det = ref (Unix.getcwd())

let outfd = ref Pervasives.stderr
let outfd_det = ref Pervasives.stderr



let node_degree = 12
let rrange = 100.
let size nodes = 
  sqrt( (float nodes) *. (3.14 *. (rrange *. rrange)) /. 
    float (node_degree))

(*
  density = area / nodes
  -> area = nodes * density (1)
  
  
  rsurface = 3.14 * (rrange^2)
  
  degree = density * rsurface
  -> density = rsurface/degree (2)
  
  
  (1) and (2) :
  area = nodes * rsurface / degree = nodes * (3.14 * (rrange^2)) / degree 
  
  side = sqrt(area)
*)

      

    

let res_summary = ref []

type trafficmatrix = HOTSPOT  | BIDIR | UNIDIR
type agent_type = AODV | GREP

let string_of_agent t =  match t with | AODV -> "AODV" | GREP -> "GREP"

module Config = 
struct
  let string_of_tmat tmat = 
    match tmat with 
      | HOTSPOT -> "hotspot "
      | BIDIR  -> "bidirectional"
      | UNIDIR -> "unidirectional"

  let tmat_of_string tmat = 
    match (String.lowercase tmat) with 
      | "hotspot" | "hot" -> HOTSPOT
      | "bidirectional" | "bi" | "bidir" -> BIDIR  
      | "unidirectional" | "uni" | "unidir" -> UNIDIR  
      | _ -> raise (Failure "Invalid format for traffic type")

  let tmat = 
    Param.stringcreate  ~name:"tmat" ~default:"Hotspot" 
      ~cmdline:true
      ~doc:"Traffic Type" ~checker:(fun s -> ignore (tmat_of_string s))
      ()

  let sources = 
    Param.intcreate  ~name:"sources" ~default:1
      ~cmdline:true
      ~doc:"Number of sources"  ()
      
  let packet_rate = 
    Param.intcreate ~name:"rate" ~default:4
      ~cmdline:true
      ~doc:"Orig rate [pkt/s]"  ()

  let speed = 
    Param.floatcreate ~name:"speed" 
      ~cmdline:true
      ~doc:"Node Speed [m/s]"  ()

  let pktssend = 
    Param.intcreate ~name:"pktssend" 
      ~cmdline:true
      ~doc:"Packets originated"  ()

  let agent_of_string = function
    | "aodv" | "AODV" -> AODV
    | "grep" | "GREP" -> GREP
    | _ -> raise (Failure "Invalid format for agent type")

  let agent = Param.stringcreate
    ~name:"agent"
    ~default:"hotspot"
    ~doc:"Traffic Type"
    ~checker:(fun s -> ignore (agent_of_string s))
    ()
end

let do_one_run() = (

    let agenttype = Config.agent_of_string (Param.get Config.agent)
    and sources = (Param.get Config.sources)
    and speed = (Param.get Config.speed)
    and pkts_to_send = (Param.get Config.pktssend)
    in

    if agenttype = GREP then Script_utils.change_seed();

    Random.init !Script_utils.seed;

    Param.set Params.x_size (size (Param.get Params.nodes));
    Param.set Params.y_size (size (Param.get Params.nodes));
    
    init_sched();
    init_world();
    
    begin match agenttype with
      | AODV -> make_aodv_nodes()
      | GREP -> make_grep_nodes();
    end;

    (* Attach a random waypoint mobility process to each node *)
    Mob_ctl.make_waypoint_mobs();
    Mob_ctl.set_speed_mps speed;
    Mob_ctl.start_all();

    Grep_hooks.set_sources sources;
    Grep_hooks.set_stop_thresh (pkts_to_send * sources);

    Nodes.iter (fun n ->
      if (n#id < sources) then (
	let dst = 
	  match Config.tmat_of_string (Param.get Config.tmat) with
	    | HOTSPOT -> ((Param.get Params.nodes)  - 1 )
	    | UNIDIR -> (((Param.get Params.nodes)  - 1 ) - n#id)
	    | BIDIR -> (sources - n#id)
	in
	if (dst <> n#id) then (
	  (* in case we have n nodes, n sources, then the n/2'th node would have
	     itself as destination*)
	  let pkt_reception() = 
	    n#trafficsource 
	      ~num_pkts:pkts_to_send 
	      ~dst 
	      ~pkts_per_sec:(Param.get Config.packet_rate) in
	  let start_time = Random.float 10.0 in
	  (Gsched.sched())#sched_in ~f:pkt_reception ~t:start_time;
	)
      )
    );
    
    let start_time = Common.get_time() in
    (Gsched.sched())#run();
    
    let avgn = avg_neighbors_per_node() in
    let end_time = Common.get_time() in
    (*  Printf.fprintf !outfd "# Avg neighbors per node is %f\n" avgn;*)

    res_summary := 
    (speed, 
    !Grep_hooks.data_pkts_orig,
    !Grep_hooks.total_pkts_sent,
    !Grep_hooks.data_pkts_recv,
    !Grep_hooks.data_pkts_sent,
    !Grep_hooks.rrep_rerr_pkts_sent,
    !Grep_hooks.rreq_pkts_sent,
    !Grep_hooks.data_pkts_drop,
    !Grep_hooks.data_pkts_drop_rerr
    )::!res_summary  ;
    
    flush !outfd
  )


let runs = ref []

(* R1: lcavpc23 Thursday noon (repeats 10 )*)
let r1 = [
  (*  repeats hotspot speed rate nodes srcs pktssend *)
  (10, UNIDIR,  0.0,  4,   1000,  40,  20);
  (10, UNIDIR,  1.0,  4,   1000,  40,  20);
  (10, UNIDIR,  2.0,  4,   1000,  40,  20);
  (10, UNIDIR,  4.0,  4,   1000,  40,  20);
  (10, UNIDIR,  6.0,  4,   1000,  40,  20);
  (10, UNIDIR,  8.0,  4,   1000,  40,  20);
  (10, UNIDIR,  12.0,  4,   1000,  40,  20);
  (10, UNIDIR,  16.0, 4,   1000,  40,  20);
]

let r5 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, HOTSPOT,  0.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  1.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  2.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  4.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  6.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  8.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  12.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  16.0,  4,   1000,  40,  20);
]

let r6 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, BIDIR,  0.0,  4,   1000,  40,  20);
  (10, BIDIR,  1.0,  4,   1000,  40,  20);
  (10, BIDIR,  2.0,  4,   1000,  40,  20);
  (10, BIDIR,  4.0,  4,   1000,  40,  20);
  (10, BIDIR,  6.0,  4,   1000,  40,  20);
  (10, BIDIR,  8.0,  4,   1000,  40,  20);
  (10, BIDIR,  12.0,  4,   1000,  40,  20);
  (10, BIDIR,  16.0,  4,   1000,  40,  20);
]


let r2 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (10, UNIDIR,  0.0,  4,   1000,  1,  200);
  (10, UNIDIR,  1.0,  4,   1000,  1,  200);
  (10, UNIDIR,  4.0,  4,   1000,  1,  200);
  (10, UNIDIR,  8.0,  4,   1000,  1,  200);
]

let r4 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (10, BIDIR,  0.0,  4,   1000,  1,  200);
  (10, BIDIR,  1.0,  4,   1000,  1,  200);
  (10, BIDIR,  4.0,  4,   1000,  1,  200);
  (10, BIDIR,  8.0,  4,   1000,  1,  200);
]


let r3 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, HOTSPOT,  8.0,  4,   50,  40,  20);
  (10, HOTSPOT,  8.0,  4,   100,  40,  20);
  (10, HOTSPOT,  8.0,  4,   200,  40,  20);
  (10, HOTSPOT,  8.0,  4,   400,  40,  20);
  (10, HOTSPOT,  8.0,  4,   600,  40,  20);
  (10, HOTSPOT,  8.0,  4,   800,  40,  20);
  (10, HOTSPOT,  8.0,  4,   1000,  40,  20);
]

let r7 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (1, UNIDIR,  12.0,  4,   200,  10,  10);
]


let aodvtots = ref (0, 0, 0, 0, 0, 0, 0, 0)
let greptots = ref (0, 0, 0, 0, 0, 0, 0, 0)

let addtots 
  (dorig, ts, dr, ds, rreps, rreqs, dd, ddrerr)
  (sp, dorig2, ts2, dr2, ds2, rreps2, rreqs2, dd2, ddrerr2)
  = 
  (dorig + dorig2, 
  ts + ts2, 
  dr + dr2,
  ds + ds2, 
  rreps + rreps2, 
  rreqs + rreqs2, 
  dd + dd2, 
  ddrerr + ddrerr2)
  
  
let rec print_summary l = 
  match l with 
    | ((sp, dorig, ts, dr, ds, rreps, rreqs, dd, ddrerr) as aodv)
      ::
      ((sp2, dorig2, ts2, dr2, ds2, rreps2, rreqs2, dd2, ddrerr2) as grep)
      ::
      rem ->
	Printf.fprintf !outfd_det "# %d %d %d %d %d %d %d %d (AODV)\n" 
	  dorig ts dr ds rreps rreqs dd ddrerr;
	Printf.fprintf !outfd_det "# %d %d %d %d %d %d %d %d (GREP)\n\n" 
	  dorig2 ts2 dr2 ds2 rreps2 rreqs2 dd2 ddrerr2;
	aodvtots := addtots !aodvtots aodv;
	greptots := addtots !greptots grep;
	print_summary rem;
      | [] -> ()
      | _ -> raise (Misc.Impossible_Case  "print_Summary")


let argspec = Myarg.Int 
  (fun i -> 
    match i with 
	1 ->
	  runs :=  r1;
	  outfile := !outfile^"/r1"^".txt";
	  outfile_det := !outfile_det^"/r1-det"^".txt";
      | 2 ->     
	  runs :=  r2;
	  outfile := !outfile^"/r2"^".txt";
	  outfile_det := !outfile_det^"/r2-det"^".txt";
      | 3 ->     
	  runs :=  r3;
	  outfile := !outfile^"/r3"^".txt";
	  outfile_det := !outfile_det^"/r3-det"^".txt";
      | 4 ->     
	  runs :=  r4;
	  outfile := !outfile^"/r4"^".txt";
	  outfile_det := !outfile_det^"/r4-det"^".txt";
      | 5 ->     
	  runs :=  r5;
	  outfile := !outfile^"/r5"^".txt";
	  outfile_det := !outfile_det^"/r5-det"^".txt";
      | 6 ->     
	  runs :=  r6;
	  outfile := !outfile^"/r6"^".txt";
	  outfile_det := !outfile_det^"/r6-det"^".txt";
      | 7 ->     
	  runs :=  r7;
	  outfile := !outfile^"/r7"^".txt";
	  outfile_det := !outfile_det^"/r7-det"^".txt";
      | _ -> failwith "No such run"
  )
  
let _ = 

(* radio range stays constant; area size changes 
   (to have different connectivity) *)
  Param.set Params.rrange rrange;
  Log.set_log_level ~level:Log.LOG_WARNING;

  Myarg.parse [("-run" , argspec, "")] (fun s -> ()) "";

  if daemon then (
    Script_utils.detach_daemon !outfile;
    outfd := !Log.output_fd;
  );
  

  outfd_det := open_out !outfile_det;
  
  List.iter (fun args ->
    let repeats = 1 in

    aodvtots :=  (0, 0, 0, 0, 0, 0, 0, 0);
    greptots :=  (0, 0, 0, 0, 0, 0, 0, 0);
    
    let s = Param.make_argspeclist () in
    
    

    let arr = Array.of_list (Str.split (Str.regexp "[ \t]+") args) in
    
    Myarg.parse_argv arr s (fun s -> ()) "You messed up!";
    
    Script_utils.dumpconfig stdout;

    Misc.repeat repeats (fun () -> 
      Param.set Config.agent "GREP";
      do_one_run ();
      Param.set Config.agent "AODV";
      do_one_run ();
    );

    print_summary !res_summary;
    
    Printf.fprintf !outfd "\n#Results:\n";
    let (dorig_a, ts_a, dr_a, ds_a, rreps_a, rreqs_a, dd_a, ddrerr_a) = !aodvtots in
    Printf.fprintf !outfd "# DOrig TSent DRec DSent RREPS RREQS DD DDRERR\n";
    Printf.fprintf !outfd "# %d %d %d %d %d %d %d %d (AODV)\n" 
      (dorig_a / repeats)
      (ts_a / repeats)
      (dr_a / repeats)
      (ds_a / repeats)
      (rreps_a / repeats)
      (rreqs_a / repeats)
      (dd_a  / repeats)
      (ddrerr_a  / repeats); 

    let (dorig_g, ts_g, dr_g, ds_g, rreps_g, rreqs_g, dd_g, ddrerr_g) = !greptots in
    Printf.fprintf !outfd "# %d %d %d %d %d %d %d %d (GREP)\n" 
      (dorig_g / repeats)
      (ts_g  / repeats)
      (dr_g  / repeats)
      (ds_g  / repeats)
      (rreps_g  / repeats)
      (rreqs_g / repeats)
      (dd_g  / repeats)
      (ddrerr_g  / repeats); 

    (* finally this uncommented line is the data per se *)
    Printf.fprintf !outfd "%0f %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n" 
      (Param.get Config.speed)
      (dorig_a / repeats)
      (ts_a / repeats)
      (dr_a / repeats)
      (ds_a / repeats)
      (rreps_a / repeats)
      (rreqs_a / repeats)
      (dd_a  / repeats)
      (ddrerr_a  / repeats)
      (dorig_g / repeats)
      (ts_g  / repeats)
      (dr_g  / repeats)
      (ds_g  / repeats)
      (rreps_g  / repeats)
      (rreqs_g / repeats)
      (dd_g  / repeats)
      (ddrerr_g  / repeats); 

    res_summary := []
  ) ["-nodes 200  -sources 10  -tmat Uni -rate 4 -speed 12 -pktssend 10"]
  


  
  

