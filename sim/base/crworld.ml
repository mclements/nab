




(** Continuous topology with reflective boundaries.
  @author Henri Dubois-Ferriere *)

open Coord
open Misc
open Common
open Printf
open Graph


(** The base class from which {!Crworld.world_lazy} and
  {!Cworld.world_greedy} inherit.

  @param x X size of World.in meters.
  @param y Y size in meters of World.
  @param rrange Radio range of nodes. Used to determine the coarseness 
  of the discrete grid (quantification) of node positions.
*)
class virtual world_common ~x ~y ~rrange  = (
  object(s)

    val mutable grid_of_nodes_ =  (Array.make_matrix 1 1 ([]:Common.nodeid_t list))
    val mutable node_positions_ =  [|(0., 0.)|]

    val world_size_x_ =  x 
    val world_size_y_ =  y
    val rrange_ = rrange
    val grid_size_x_ = (f2i (x /. rrange)) + 1
    val grid_size_y_ = (f2i (y /. rrange)) + 1

    val rrange_sq_ = rrange ** 2.0
      
    val mutable mob_mhooks = []

    val initial_pos = (0.0, 0.0)

      
    (** See {!Worldt.lazy_world_t.neighbors}.
      Virtual since implementation of neighbor lookup is different for lazy vs  greedy. *)
    method virtual neighbors : Common.nodeid_t -> Common.nodeid_t list

    (** This method is called each time a node has moved. 
      Virtual since implementation of neighbor lookup is different for lazy vs  greedy. *)
    method virtual private update_node_neighbors_ : ?oldpos:Coord.coordf_t -> Common.nodeid_t -> unit



    initializer (
      grid_of_nodes_ <- 
      (Array.make_matrix grid_size_x_ grid_size_y_ []);
      node_positions_ <- Array.make (Param.get Params.nodes) initial_pos;

      Log.log#log_notice (lazy 
	(sprintf "New World : size <%f,%f>, rrange %f, #nodes %d" 
	  x y rrange (Param.get Params.nodes))
      );
    )

    (* takes a 'real' position  (ie, in meters) and returns the 
       discrete grid position *)
    method private pos_in_grid_ pos = coord_f2i (coord_floor (pos ///. rrange_))

    method random_pos  = (
      let pos = (Random.float world_size_x_, Random.float world_size_y_) in
      pos
    )

    method virtual get_nodes_within_radius :  nid:Common.nodeid_t -> radius:float -> Common.nodeid_t list
    method virtual boundarize : Coord.coordf_t -> Coord.coordf_t
    method virtual dist_coords :  Coord.coordf_t -> Coord.coordf_t -> float
    method virtual are_neighbors : Common.nodeid_t -> Common.nodeid_t -> bool
      
    method dist_nodeids id1 id2 = s#dist_coords (node_positions_.(id1)) (node_positions_.(id2))

    method private slow_compute_neighbors_ nid = (
      let neighbors = ref [] in
      Nodes.iteri 
	(fun cand_id _ -> if s#are_neighbors nid cand_id  then 
	  neighbors := (cand_id)::!neighbors);
      !neighbors;
    )

    method private grid_neighbors_ pos = (
      let gridpos = s#pos_in_grid_ pos in
      let grid_at_pos p = 
	if (s#is_in_grid p)  
	then grid_of_nodes_.(xx p).(yy p) 
	else [] 
      in
      let north = 0,1
      and south = 0,-1 
      and west = -1,0 
      and east = 1,0 in
      let northeast = north +++ east 
      and northwest = north +++ west
      and southeast = south +++ east
      and southwest = south +++ west in
      
      grid_at_pos gridpos @
      grid_at_pos (gridpos +++ north) @
      grid_at_pos (gridpos +++ east) @
      grid_at_pos (gridpos +++ west) @
      grid_at_pos (gridpos +++ south) @
      grid_at_pos (gridpos +++ northeast) @
      grid_at_pos (gridpos +++ southeast) @
      grid_at_pos (gridpos +++ northwest) @
      grid_at_pos (gridpos +++ southwest)
    )
      
    method private compute_neighbors_ nid = 
      List.filter (fun cand_nid -> s#are_neighbors nid cand_nid)  
	(s#grid_neighbors_ node_positions_.(nid))

    method neighbors_consistent = (
      let consistent = ref true in

      (* Check that neighbors are commutative *)
      let commutative() = (
	Nodes.iter 
	(fun n -> 
	  List.iter 
	  (fun ngbr_id -> consistent := !consistent && 
	    List.mem n#id (s#neighbors ngbr_id)
	  )  (s#neighbors n#id)
	);

	!consistent
      ) || raise (Failure "Neighbors not commutative")
      in

      (* Check that all nodes have the correct neigbhors *)
      let correct_neighbors() = (
	Nodes.iter
	(fun n -> 
	  if not (Misc.list_same 
	    (s#neighbors n#id)
	    (s#compute_neighbors_ n#id)) then (
	    Printf.printf "node %d: \n" n#id;
	    List.iter (fun i -> Printf.printf "%d " i) (s#neighbors n#id);
	    Printf.printf "\n";
	    List.iter (fun i -> Printf.printf "%d " i) (s#compute_neighbors_ n#id);
	    Printf.printf "\n";
	  );

	  consistent := !consistent && 
	  (Misc.list_same
	    (s#neighbors n#id)
	    (s#compute_neighbors_ n#id)));
	!consistent
      ) || 
	raise (Failure "Neighbors not correct")
      in

      (* Check that all nodes have the correct neigbhors using slow method *)
      let slow_correct_neighbors() = (
	Nodes.iter
	(fun n -> consistent := !consistent && 
	  (Misc.list_same 
	    (s#neighbors n#id)
	    (s#slow_compute_neighbors_ n#id)));
	!consistent
      ) || raise (Failure "Neighbors not correct (slow_compute_neighbors)")
      in
      commutative()
      &&
      correct_neighbors()
      &&
      slow_correct_neighbors()
    )
      
    method nodepos nid = node_positions_.(nid)

    method movenode ~nid ~newpos  = (
      assert (not (xx newpos < 0.0) || xx newpos > Param.get Params.x_size ||
      yy newpos < 0.0 || yy newpos > Param.get Params.y_size);

      (* update local data structures (grid_of_nodes) with new pos, 
	 then update the node and neighbor node objects *)
      
      let (newx, newy) = s#pos_in_grid_ newpos in
      
      let oldpos = (node_positions_.(nid)) in
      node_positions_.(nid) <- newpos;

      let (oldx, oldy) = (s#pos_in_grid_ oldpos) in
      
      if (oldx, oldy) <> (newx, newy) then (
	(* only update grid_of_nodes if node moved to another slot *)
	
	grid_of_nodes_.(newx).(newy) <- nid::grid_of_nodes_.(newx).(newy);      
	
	assert (List.mem nid (grid_of_nodes_.(oldx).(oldy)));
	grid_of_nodes_.(oldx).(oldy) <- list_without
	  grid_of_nodes_.(oldx).(oldy) nid;      
      );
      s#update_node_neighbors_ ~oldpos nid;

(*      ignore (s#neighbors_consistent || failwith "not consistent");*)

      List.iter 
	(fun mhook -> mhook newpos nid )
	mob_mhooks;
    )

    method add_mob_mhook  ~hook =
      mob_mhooks <- hook::mob_mhooks
	
    method init_pos ~nid ~pos = (
      (* update local data structures (grid_of_nodes) with new pos, 
	 then update the node and neighbor node objects *)

      let (newx, newy) = s#pos_in_grid_ pos in

      if node_positions_.(nid) <> initial_pos then 
	failwith "world.init_pos: node already positioned";
      
      node_positions_.(nid) <- pos;

(*
	Printf.printf "%s %d %d %d %d \n" 
	(Coord.sprintf pos)
	newx
	newy
	(Array.length grid_of_nodes_)
	(Array.length grid_of_nodes_.(0));
*)

      assert (not (List.mem nid grid_of_nodes_.(newx).(newy)));
      
      grid_of_nodes_.(newx).(newy) <- nid::grid_of_nodes_.(newx).(newy);      
      
      s#update_node_neighbors_ nid;
      
      List.iter 
	(fun mhook -> mhook pos nid)
	mob_mhooks;
    )
      

    method private is_in_grid p = 
      (xx p) >= 0 && (yy p) >= 0 && 
      ((xx p) < grid_size_x_) && ((yy p) < grid_size_y_)



    (* Returns nodes in squares that are touched by a ring of unit width. 
       List may have repeated elements.
       radius: outer radius of ring *)
    method private get_nodes_in_ring ~center_m ~radius_m = (

      let grid_squares_at_radius r = (
	let coords = (
	  match r with
	    | rad when (rad <= rrange_) -> 
		let gridpos = s#pos_in_grid_ center_m in
		
		let north = 0,1
		and south = 0,-1 
		and west = -1,0 
		and east = 1,0 in
		let northeast = north +++ east 
		and northwest = north +++ west
		and southeast = south +++ east
		and southwest = south +++ west in
		
		[gridpos;
		(gridpos +++ north);
		(gridpos +++ east);
		(gridpos +++ west);
		(gridpos +++ south);
		(gridpos +++ northeast);
		(gridpos +++ southeast);
		(gridpos +++ northwest);
		(gridpos +++ southwest)
		]
	    | rad  -> 
		(* xxx/ gridsize can be rectangular *)
		Crsearch.xsect_grid_and_circle 
		~center_m:center_m 
		~radius_m:rad
		~worldsize_x_m:world_size_x_
		~worldsize_y_m:world_size_y_
		~boxsize_m:rrange_
	) in
	List.filter (fun p -> s#is_in_grid p) coords
      ) in
      
      let inner_squares = grid_squares_at_radius (radius_m -. rrange_)
      and outer_squares = grid_squares_at_radius radius_m
      in 
      let squares = list_unique_elements (
	inner_squares @ 
	outer_squares
      ) in
      let is_in_ring = (fun n -> 
	((s#dist_coords center_m node_positions_.(n)) <=  radius_m) && 
	((s#dist_coords center_m node_positions_.(n)) >= (radius_m -. rrange_))) in
      
      List.fold_left (fun l sq -> 
	l @
	(List.filter is_in_ring grid_of_nodes_.(xx sq).(yy sq))
      ) [] squares
    )


    method find_closest ~pos ~f = (
      let diagonal_length = 
	(ceil 
	  (sqrt
	    ( 
	      (world_size_x_ ** 2.0)
	      +.
	      (world_size_y_ ** 2.0)
	    )
	  ))
      in
      let r = ref rrange in

      let closest = ref None in 

      while (!r <= diagonal_length) && (!closest = None) do
	let candidates = Misc.list_unique_elements
	  (s#get_nodes_in_ring ~center_m:pos ~radius_m:!r) in
	let (closest_id, closest_dist) = (ref None, ref max_float) in
	List.iter 
	  (fun nid -> 
	    match f nid with
	      | true ->
		  if (s#dist_coords pos node_positions_.(nid)) < !closest_dist then (
		    closest_id := Some nid;
		    closest_dist := (s#dist_coords pos node_positions_.(nid))
		  )
	      | false -> ()
	  ) candidates;
	closest := !closest_id;
	r := !r +. rrange_
      done;

      (*
	let slow_closest = (s#slow_find_closest ~pos:pos ~f:f) 
	in
	if (!closest <> slow_closest) then (
	if ((s#dist_coords (Nodes.node(o2v !closest))#pos pos) < s#dist_coords
	(Nodes.node(o2v slow_closest))#pos pos) then 
	Printf.printf "We got a closest that is closer!!, radius %f\n" !r
	else if (s#dist_coords (Nodes.node(o2v !closest))#pos pos >
	s#dist_coords (Nodes.node(o2v slow_closest))#pos pos) then 
	Printf.printf "We got a closest that is further,  radius %f\n" !r
	);
	flush stdout;
      *)
      !closest
    )
      
      
    method private slow_find_closest ~pos ~f = (
      let (closest_id, closest_dist) = (ref None, ref max_float) in
      Nodes.iter 
	(fun n -> 
	  match f n with
	    | true ->
		if (s#dist_coords pos node_positions_.(n#id)) < !closest_dist then (
		  closest_id := Some n#id;
		  closest_dist := (s#dist_coords pos node_positions_.(n#id))
		)
	    | false -> ()
	);
      !closest_id
    )


    method get_nodes_within_radius  ~nid ~radius = (
      
      let radius_sq = radius ** 2.0 in
      let center = node_positions_.(nid) in
      let l = ref [] in
      Nodes.iteri (fun cand_id _ -> if s#dist_coords center node_positions_.(cand_id) <= radius then l := (cand_id)::!l);
      !l
    )

    (*  method scale_unit f = f /. gridsize_*)

    method project_2d (x, y) =  (x /. world_size_x_, y /. world_size_y_)

    method is_connected () = (
      (* Create a graph object reflecting current connectivity *)
      let g = (Graph.make_ 0 (Param.get Params.nodes) Graph.Directed) in
      Nodes.iter (fun n -> Graph.add_node_ g n#id);
      Nodes.iteri (fun i _ -> 
	List.iter (fun ngbr -> Graph.add_edge_ g i ngbr (s#dist_nodeids i ngbr)) 
	(s#neighbors i));
      (* Iterate over all src-dst pairs and check if there is a route *)
      try 
	Graph.itern_ (fun src -> 
	  Graph.itern_ (fun dst -> 
	    ignore (Graph.route_dij_ g src dst);
	  ) g
	) g;

	true
      with 
	| (Failure "No_route") -> false
    )

  end
)


(** Implementation of {!Worldt.lazy_world_t} using a greedy approach to maintaining
  neighbor positions. In other words, a node's neighbors are only re-computed
  each time it moves. This is usually slower than the lazy approach of
  {!Crworld.world_lazy}, but is necessary if using the [add_new_ngbr_hook]
  facility of {!Worldt.lazy_world_t}.

  @param x X size of World.in meters.
  @param y Y size in meters of World.
  @param rrange Radio range of nodes. Used to determine the coarseness 
  of the discrete grid (quantification) of node positions.
*)
class virtual world_greedy  = (
  object(s)

    val ngbrs = (Array.make (Param.get Params.nodes) ([]:Common.nodeid_t list))
      (* not exposed in virtual class world_ because the way it is
	 maintained up-to-date is different depending on lazy/greedy style *)

    val mutable new_ngbr_hooks = 
      (Array.make (Param.get Params.nodes) ([]:((Common.nodeid_t -> unit) list)))

    method add_new_ngbr_hook nid ~hook =
      new_ngbr_hooks.(nid) <- new_ngbr_hooks.(nid) @ [hook]

    method private update_node_neighbors_ ?oldpos nid = (

      (* 
	 For all neighbors, do a lose_neighbor_ on the neighbor and on this node.
	 Then, compute new neighbors, and add them to this node and to the neighbors.
      *)

      (* not really sure if redefining List.mem here helps performance
	 (intention is to avoid polymorphic = ) *)

      let rec mem (x:int) = function
	  [] -> false
	| a::l -> a = x || mem x l
      in

      let old_neighbors = ngbrs.(nid) in
      let new_neighbors = s#compute_neighbors_ nid in

      let exits = List.filter (fun nid -> not (mem nid new_neighbors)) old_neighbors
      and entries = List.filter (fun nid -> not (mem nid old_neighbors)) new_neighbors

      in
      List.iter 
	(fun i -> 
	  s#lose_neighbor_ ~nid  ~ngbrid:i;
	  s#lose_neighbor_ ~nid:i ~ngbrid:nid
	) exits;

      List.iter 
	(fun i -> 
	  s#add_neighbor_ ~nid ~ngbrid:i;
	  if i <> nid then
	    (* don't add twice for node itself *)
	    s#add_neighbor_ ~nid:i ~ngbrid:nid
	) entries
    )


    (* adds a new neighbor ngbrid to nid. 
       does NOT do the symetric operation *)
    method private add_neighbor_ ~nid ~ngbrid = (
      assert (not (List.mem ngbrid ngbrs.(nid) ));
      List.iter 
	(fun hook -> hook ngbrid)
	new_ngbr_hooks.(nid);

      ngbrs.(nid) <- ngbrid::ngbrs.(nid);
    )

    (* removes neighbor ngbrid from nid. 
       does NOT do the symetric operation *)
    method private lose_neighbor_ ~nid ~ngbrid = (
      assert (List.mem ngbrid ngbrs.(nid) );
      ngbrs.(nid) <- Misc.list_without ngbrs.(nid) ngbrid
    )

    method neighbors nid =  ngbrs.(nid)
  end
)





(** Implementation of {!Worldt.lazy_world_t} using a lazy approach to maintaining
  neighbor positions. In other words, a node's neighbors are only computed
  when needed (for example by when the [#neighbors] method is invoked).
  This is usually faster than the greedy approach of
  {!Crworld.world_greedy}, but disallows using the [add_new_ngbr_hook]
  facility of {!Worldt.lazy_world_t}.

  @param x X size of World.in meters.
  @param y Y size in meters of World.
  @param rrange Radio range of nodes. Used to determine the coarseness 
  of the discrete grid (quantification) of node positions.
*)
class virtual world_lazy = (
  object(s)

    val ngbrs = (Array.make (Param.get Params.nodes) ([]:Common.nodeid_t list))
      (* not exposed in virtual class world_ because the way it is
	 maintained up-to-date is different depending on lazy/greedy style *)

    val dirty =  (Array.make (Param.get Params.nodes) true)

    method neighbors nid = (
      if dirty.(nid) then ngbrs.(nid) <- s#compute_neighbors_ nid;
      dirty.(nid) <- false;
      ngbrs.(nid)
    )

    method private update_node_neighbors_ ?oldpos nid = 

      let nodepos = s#nodepos nid in 
      List.iter (fun n -> dirty.(n) <- true) (s#grid_neighbors_ nodepos);
      
      match oldpos with 
	  (* if the node moved across a grid boundary, then potentially nodes
	     from its previous grid_neighbors are dirty as well *)
	| Some p -> 
	    let (newx, newy) = s#pos_in_grid_ nodepos
	    and (oldx, oldy) = s#pos_in_grid_ p in
	    if (oldx, oldy) <> (newx, newy) then 
	      List.iter (fun n -> dirty.(n) <- true) (s#grid_neighbors_ p)
	| None -> ()
	    
  end
)

class virtual reflecting_world ~x ~y ~rrange = (
  object(s)

    inherit world_common ~x ~y ~rrange

    method boundarize pos = 

      let newx = ref (xx pos) and newy = ref (yy pos) in 
      if !newx >  world_size_x_ then 
	newx := (2.0 *. world_size_x_) -. !newx
      else if !newx < 0.0 then
	newx := (-1.0) *. !newx;
      if !newy > world_size_y_  then  
	newy := (2.0 *. world_size_y_) -. !newy
      else if !newy < 0.0 then
	newy := (-1.0) *. !newy;

      assert (!newx >= 0.0 && !newx <=  world_size_x_ && !newy >= 0.0 && !newy <=  world_size_y_);
      (!newx, !newy)
      
    method dist_coords a b = sqrt (Coord.dist_sq a b)
    method are_neighbors nid1 nid2 = 
      nid1 <> nid2 && ((Coord.dist_sq (node_positions_.(nid1)) (node_positions_.(nid2))) <= rrange_sq_)

  end
)


class virtual taurus_world ~x ~y ~rrange = (
  object(s)

    inherit world_common ~x ~y ~rrange

    method boundarize pos = pos
    method dist_coords a b = sqrt (Coord.dist_sq a b)
    method are_neighbors nid1 nid2 = 
      nid1 <> nid2 && ((Coord.dist_sq (node_positions_.(nid1)) (node_positions_.(nid2))) <= rrange_sq_)

  end
)


class lazy_reflecting_world ~x ~y ~rrange : Worldt.lazy_world_t = (
  object(s)
    inherit world_lazy
    inherit reflecting_world ~x ~y ~rrange
  end
)

class greedy_reflecting_world ~x ~y ~rrange : Worldt.greedy_world_t = (
  object(s)
    inherit world_greedy
    inherit reflecting_world ~x ~y ~rrange
  end
)

class lazy_taurus_world ~x ~y ~rrange : Worldt.lazy_world_t = (
  object(s)
    inherit world_lazy
    inherit taurus_world ~x ~y ~rrange
  end
)

class greedy_taurus_world ~x ~y ~rrange : Worldt.greedy_world_t = (
  object(s)
    inherit world_greedy
    inherit taurus_world ~x ~y ~rrange
  end
)




class epflworld ~x ~y ~rrange = 
object(s)
  inherit lazy_reflecting_world ~x ~y ~rrange
  method random_pos =  
    let nodeind = Random.int 113 in
    Read_coords.box_centeri nodeind
end


