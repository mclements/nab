(*
 *
 *  NAB - Network in a Box
 *  Henri Dubois-Ferriere, LCA/LCAV, EPFL
 * 
 *  Copyright (C) 2004 Laboratory of Audiovisual Communications (LCAV), and
 *  Laboratory for Computer Communications and Applications (LCA), 
 *  Ecole Polytechnique Federale de Lausanne (EPFL),
 *  CH-1015 Lausanne, Switzerland
 *
 *  This file is part of NAB. NAB is free software; you can redistribute it 
 *  and/or modify it under the terms of the GNU General Public License as 
 *  published by the Free Software Foundation; either version 2 of the License,
 *  or (at your option) any later version. 
 *
 *  NAB is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 *  details (enclosed in the file GPL). 
 *
 *)

(* $Id$ *)



open Misc
open GMain


let t = ref (Time.get_time())

let nstacks = 2

let routes = Array.init nstacks (fun _ -> (Route.create()))
let clear_routes() =  Array.iteri (fun i _ -> routes.(i) <- (Route.create())) routes

let start_stop_btn = ref None
let start_stop_tab:GPack.table option ref = ref None
let ss_btn() = o2v !start_stop_btn
let ss_tab() = o2v !start_stop_tab
let choose_route_btn = ref None
let rt_btn() = o2v !choose_route_btn

let show_nodes = ref true
let show_route_lines = ref true
let show_route_anchors = ref true
let show_route_disks = ref true
let show_connectivity = ref false
let text_entry = ref false  

type proto = EASE | GREASE
let proto = ref GREASE
let stack_of_proto() = match !proto with GREASE -> 0 | EASE -> 1 


let running = ref false

let route_portion = ref 1.0

let dst = 0

let run() = (

  Gui_gtk.set_expose_event_cb (fun _ -> true);
  
  t := (Time.get_time());
  let continue() = ((Time.get_time()) < !t +. 1.0) in
  (Sched.s())#run_until~continue;

  if !show_nodes  then  Gui_ops.draw_all_nodes(); 
  Gui_gtk.draw ~clear:true ();
  true
)
  


let refresh ?(clear=true) ()  = (

  Gui_gtk.draw ~clear ();

  if !show_nodes  then  Gui_ops.draw_all_nodes(); 
  if !show_connectivity  then  Gui_ops.draw_connectivity(); 
  (*
    Gui_ops.draw_all_routes 
    (); 
    Gui_ops.draw_all_boxes(); 
  *)

    Gui_ops.draw_ease_route 
      ~lines:!show_route_lines
      ~anchors:!show_route_anchors
      ~disks:!show_route_disks
      ~portion:!route_portion
      (Gui_conv.ease_route_nodeid_to_pix routes.(stack_of_proto()))

)



let start_stop () = (
  (* if we are in the middle of choosing a node, should we cancel all state? *)
  
  match !running with
    | true -> 
	Gui_gtk.txt_msg "Nodes are frozen ";
	Mob_ctl.stop_all();
	Gui_ctl.stop();
	running := not !running;
	refresh ();
    | false -> 
	Gui_gtk.txt_msg "Nodes are moving ";
	Mob_ctl.start_all();
	clear_routes();
	Gui_ctl.startsim ~sim_tick:1. ~rt_tick_ms:1000 ~display_cb:refresh;
	running := not !running;
)




let set_src nid = (

  Gui_gtk.txt_msg (Printf.sprintf "Route from %d to %d" nid dst);
  Log.log#log_always (lazy (Printf.sprintf "Destination is at %s"
    (Coord.sprintf (Nodes.gpsnode dst)#pos)));
  
  clear_routes();
  Gui_hooks.routes_done := 0;
  let r = [|ref []; ref []|] in
  
  for stack = 0 to nstacks - 1  do
    let in_mhook = Gui_hooks.ease_route_pktin_mhook r.(stack) in
    let out_mhook = Gui_hooks.ease_route_pktout_mhook r.(stack) in
    Nodes.gpsiter (fun n -> n#clear_pkt_mhooks ~stack ());
    Nodes.gpsiter (fun n -> n#add_pktin_mhook ~stack in_mhook);
    Nodes.gpsiter (fun n -> n#add_pktout_mhook ~stack out_mhook);
  done;

  (Nodes.node nid)#originate_app_pkt ~dst;
  
  (Sched.s())#run_until 
  ~continue:(fun () -> 
    !Gui_hooks.routes_done < nstacks;
  );
  
  routes.(0) <- !(r.(0));
  routes.(1) <- !(r.(1));

(*  Printf.printf "%s\n" (Route.sprintnid ( !routeref));flush stdout;*)
(*
  ignore (Route.ease_route_valid !routeref 
    ~dst
    ~src:nid);
*)
  

  (* For some reason, if i don't do this twice, the anchors are not drawn, and
     only appear if i force the window to refresh (by say passing another window
     over it. Not sure if this is my bug or lablgtk's, but with this ugly
     workaround it goes away. *)
  refresh();
  refresh();
)



let choose_node () = (
  (* call Mob_ctl.stop_all always because node mobs might not be stopped even 
     when  !running is false. *)
  Mob_ctl.stop_all();
  
  if !running then (
    start_stop();
  );
  if !text_entry then
    Gui_ops.dialog_pick_node ~default:92 ~node_picked_cb:set_src ()
  else
    Gui_ops.user_pick_node ~msg:"Pick a node, dude" ~node_picked_cb:set_src ()
)


  
let create_buttons_common() = (

  let ss_tab = (GPack.table ~rows:8 ~columns:1 ~homogeneous:false 
    ~row_spacings:0 ~col_spacings:0 ~border_width:0
    ~packing:(Gui_gtk.hpacker()) ()) in

  start_stop_btn := Some (GButton.toggle_button ~draw_indicator:false
    ~label:"start/stop" ());
  ignore ((ss_btn())#connect#released ~callback:(start_stop));
  ss_tab#attach (ss_btn())#coerce ~left:0 ~top:0 ~right:1 ~bottom:1
    ~xpadding:0 ~ypadding:0  ~expand:`NONE;

  choose_route_btn := Some (GButton.toggle_button ~draw_indicator:false
    ~label:"draw a route" ()) ;
  ignore ((rt_btn())#connect#released ~callback:(choose_node));
  ss_tab#attach (rt_btn())#coerce ~left:0 ~top:1 ~right:1 ~bottom:2
    ~xpadding:0 ~ypadding:0  ~expand:`NONE;

  ss_tab
)

let create_buttons_ease() = (

  let ss_tab = create_buttons_common() in 

  let checkbox_tab = (GPack.table ~rows:1 ~columns:4 ~homogeneous:false 
    ~row_spacings:0 ~col_spacings:0 ~border_width:0
    ()) in

  ss_tab#attach checkbox_tab#coerce ~left:0 ~top:2 ~right:1 ~bottom:8
    ~xpadding:0 ~ypadding:0  ~expand:`BOTH;
(*  let box2 = GPack.vbox ~spacing: 0 ~border_width: 10
    ~packing: box1#pack () in*)
  

  let checkboxlist = [
    ("Hide nodes", show_nodes, 0, 0);
    ("Hide Anchors", show_route_anchors, 0, 1);
    ("Hide Directions", show_route_lines, 0, 2);
    ("Hide Disks", show_route_disks, 0, 3);
    ("Text", text_entry, 0, 4);
  ] in
  
  List.iter (fun (txt, boolref, left, top) ->
    let btn = (GButton.check_button ~label:txt
      ()) in
    checkbox_tab#attach btn#coerce ~left ~top ~right:(left + 1) 
      ~bottom:(top +  1)  ~xpadding:0 ~ypadding:0  ~expand:`NONE;
    
    ignore (btn#connect#released 
      ~callback:(fun _ -> 
	boolref := not !boolref;
	ignore (refresh ()) ;
      )
    )) checkboxlist;

  
  let btn1 =  GButton.radio_button ~label:"GREASE" ~active:true  ()  in

  checkbox_tab#attach btn1#coerce ~left:0 ~top:5 ~right:1 ~bottom:6 ~expand:`NONE;
  ignore (btn1#connect#released ~callback:(fun () -> proto := GREASE; ignore (refresh())));
  
  let btn2 = GButton.radio_button ~group:btn1#group ~label:"EASE" ()  in

  checkbox_tab#attach btn2#coerce ~left:0 ~top:6 ~right:1 ~bottom:7 ~expand:`NONE;
  ignore (btn2#connect#released ~callback:(fun () -> proto := EASE; ignore (refresh())));

  let adj =
    GData.adjustment ~lower:0. ~upper:1001. ~step_incr:1. ~page_incr:100. () in
  let sc = GRange.scale `HORIZONTAL ~adjustment:adj ~draw_value:false
    ~packing:(Gui_gtk.vpacker()) () in
    
  ignore (adj#connect#value_changed
    ~callback:(fun () -> 
      route_portion := 
      if       adj#value > 990.0 then 1.0 else
      adj#value/.1000.;
      ignore (refresh());
    ));

  Gui_gtk.set_expose_event_cb (fun _ -> refresh(); false);

(*  ignore (counter#connect#changed ~callback:(fun n -> 
    Gui_gtk.txt_msg (Printf.sprintf "New value %s.." (string_of_int n))));
*)

)


   
(* to kill: window#destroy ()*)

