(*                                  *)
(* mws  multihop wireless simulator *)
(*                                  *)

(* Continuous topology with reflective boundaries *)

open Coord
open Misc
open Common
open Printf

(* This class duplicates code from  contTaurusTop.ml, keep in mind when 
   changing things *)

class crworld ~node_cnt : World.world_t = 
object(s)

  val mutable grid_of_nodes_ =  (Array.make_matrix 1 1 [])
    
  val mutable gridsize_ =  1.0 (* in practice an int, but stored as float to avoid many i2f's*)
  val mutable center_ =  [|0.5; 0.5|]

  initializer (
    let g = round (sqrt (i2f node_cnt)) in
    gridsize_ <- g;
    center_ <- [|g /. 2.0; g /. 2.0|];
    grid_of_nodes_ <- (Array.make_matrix (f2i g) (f2i g) []);
  )

  method private pos_in_grid_ pos = coord_f2i (coord_floor pos)

  method random_pos  = (
    let pos = (Random.float gridsize_, Random.float gridsize_) in
    pos
  )

  method private reflect pos = (
    let newx = ref (xx pos) and newy = ref (yy pos) in 
    if !newx >  gridsize_ then 
      newx := (2.0 *. gridsize_) -. !newx
    else if !newx < 0.0 then
      newx := (-1.0) *. !newx;
    if !newy > gridsize_  then  
      newy := (2.0 *. gridsize_) -. !newy
    else if !newy < 0.0 then
      newy := (-1.0) *. !newy;
    assert (!newx >= 0.0 && !newx <  gridsize_ && !newy >= 0.0 && !newy <  gridsize_);
    (!newx, !newy)
  )

  method boundarize pos = s#reflect pos

  method dist_coords a b = sqrt (Coord.dist_sq a b)
  method dist_nodes n1 n2 = s#dist_coords n1#pos n2#pos
  method dist_nodeids id1 id2 = s#dist_coords (Nodes.node(id1))#pos (Nodes.node(id2))#pos
  method neighbors n1 n2 = (s#dist_coords n1#pos n2#pos) <= 1.0
    
  method private slow_compute_neighbors_ node = (
    let neighbors = ref [] in
    Nodes.iter 
      (fun a_node -> if s#neighbors node a_node  then 
	neighbors := (a_node#id)::!neighbors);
    !neighbors;
  )

  method private compute_neighbors_ node = (
    let gridpos = s#pos_in_grid_ node#pos in
    let grid_at_pos p = 
      if (xx p) >= 0 && (yy p) >= 0 && 
	(xx p) < (f2i gridsize_) && (yy p) < (f2i gridsize_)
      then grid_of_nodes_.(xx p).(yy p) else [] 
    in
    let north = 0,1
    and south = 0,-1 
    and west = -1,0 
    and east = 1,0 in
    let northeast = north +++ east 
    and northwest = north +++ west
    and southeast = south +++ east
    and southwest = south +++ west in
    
    let candidates = 
      grid_at_pos gridpos @
      grid_at_pos (gridpos +++ north) @
      grid_at_pos (gridpos +++ east) @
      grid_at_pos (gridpos +++ west) @
      grid_at_pos (gridpos +++ south) @
      grid_at_pos (gridpos +++ northeast) @
      grid_at_pos (gridpos +++ southeast) @
      grid_at_pos (gridpos +++ northwest) @
      grid_at_pos (gridpos +++ southwest)
    in
    List.filter (fun a_node -> s#neighbors node (Nodes.node(a_node))) candidates
  )

  method neighbors_consistent = (
    let consistent = ref true in

    (* Check that neighbors are commutative *)
    let commutative() = (
      Nodes.iter 
      (fun n -> 
	List.iter 
	(fun n_id -> consistent := !consistent && 
	  ((Nodes.node(n_id))#is_neighbor n))
	n#neighbors
      );
      !consistent
    ) || raise (Failure "Neighbors not commutative")
    in

    (* Check that all nodes have the correct neigbhors *)
    let correct_neighbors() = (
    Nodes.iter
      (fun n -> consistent := !consistent && 
	(Misc.list_same 
	  n#neighbors
	  (s#compute_neighbors_ n)));
      !consistent
    ) || raise (Failure "Neighbors not correct")
    in
    commutative()
    &&
    correct_neighbors()
  )
    
  method update_pos ~node ~oldpos_opt = (
    (* update local data structures (grid_of_nodes) with new pos, 
       then update the node and neighbor node objects *)
    
    let index = node#id in
    let newpos = node#pos in

    let (newx, newy) = s#pos_in_grid_ newpos in

    let _ = 

	match oldpos_opt with
	    
	  | None ->  (
	      assert (not (List.mem index grid_of_nodes_.(newx).(newy)));
	      grid_of_nodes_.(newx).(newy) <- index::grid_of_nodes_.(newx).(newy);      
	      (* node is new, had no previous position *)
	    )
	  | Some oldpos -> (
	      let (oldx, oldy) = (s#pos_in_grid_ oldpos) in
	      
	      if (oldx, oldy) <> (newx, newy) then (
		(* only update grid_of_nodes if node moved to another slot *)
		
		grid_of_nodes_.(newx).(newy) <- index::grid_of_nodes_.(newx).(newy);      
		assert (List.mem index (grid_of_nodes_.(oldx).(oldy)));
		grid_of_nodes_.(oldx).(oldy) <- list_without
		  grid_of_nodes_.(oldx).(oldy) index;      
	      )
	    )
	      (* note for checkin comment: remove catch because it was
		 assuming wrongly that there was a single possible error *)
    in

    s#update_node_neighbors_ node;
  )
    

  method private update_node_neighbors_ node = (

    (* 
       For all neighbors, do a lose_neighbor on the neighbor and on this node.
       Then, compute new neighbors, and add them to this node and to the neighbors.
    *)

    let old_neighbors = node#neighbors in
    let new_neighbors = s#compute_neighbors_ node in
    let old_and_new = old_neighbors @ new_neighbors in

    let changed_neighbors = 
    (* nodes which have changed status (entered or exited neighborhood)
       are those which are in only one of old_neighbors and new_neighbors *)
      List.fold_left (fun l n -> 
	if ((Misc.list_count_element ~l:old_and_new ~el:n) = 1) then
	  n::l 
	else 
	  l) [] old_and_new 
    in
    List.iter 
      (fun i -> 

	if node#is_neighbor (Nodes.node i) then ( (* these ones left *)
	  node#lose_neighbor (Nodes.node i);
	  (Nodes.node i)#lose_neighbor node

	) else (	  (* these ones entered *)

	  node#add_neighbor (Nodes.node i);
	  if i <> node#id then
	    (* don't add twice for node itself *)
	    (Nodes.node i)#add_neighbor node
	)
      ) changed_neighbors
  )


    (* Returns nodes in squares that are touched by a ring of unit width. 

       List may have repeated elements.
       radius: outer radius of ring *)

  method private get_nodes_in_ring ~center ~radius = (
    
    let pos_in_grid p = 
      (xx p) >= 0 && (yy p) >= 0 && 
      (xx p) < (f2i gridsize_) && (yy p) < (f2i gridsize_) 
    in
    
    let grid_squares_at_radius r = (
	let coords = (
	  match r with
	    | 0 -> []
	    | 1 -> 
		let gridpos = s#pos_in_grid_ center in
		
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
	    | r  -> 
		Crsearch.xsect_grid_and_circle ~center:center ~radius:(i2f r) ~gridsize:gridsize_
	) in
	List.filter (fun p -> pos_in_grid p) coords
      ) in
    
      let inner_squares = grid_squares_at_radius (radius - 1)
      and outer_squares = grid_squares_at_radius radius
      in 
      let squares = list_unique_elements (
	inner_squares @ 
	outer_squares
      ) in
      let is_in_ring = (fun n -> 
	((s#dist_coords center (Nodes.node(n))#pos) <= (i2f radius)) && 
	((s#dist_coords center (Nodes.node(n))#pos) >= (i2f (radius - 1)))) in
      
      List.fold_left (fun l sq -> 
	l @
	(List.filter is_in_ring grid_of_nodes_.(xx sq).(yy sq))
      ) [] squares
  )


  method find_closest ~pos ~f = (
    let diagonal_length = f2i (ceil (sqrt (2.0 *. (gridsize_ ** 2.0)))) in
    let i = ref 1 in

    let closest = ref None in 

    while (!i <= diagonal_length) && (!closest = None) do
      let candidates = Misc.list_unique_elements
	(s#get_nodes_in_ring ~center:pos ~radius:!i) in
      let (closest_id, closest_dist) = (ref None, ref max_float) in
      List.iter 
	(fun nid -> 
	  let n = Nodes.node(nid) in
	  match f n with
	    | true ->
		if (s#dist_coords pos n#pos) < !closest_dist then (
		  closest_id := Some n#id;
		  closest_dist := (s#dist_coords pos n#pos)
		)
	    | false -> ()
	) candidates;
      closest := !closest_id;
      incr i
    done;
(*
    let slow_closest = (s#slow_find_closest ~pos:pos ~f:f) 
    in
    if (!closest <> slow_closest) then (
      if ((s#dist_coords (Nodes.node(o2v !closest))#pos pos) < s#dist_coords
	(Nodes.node(o2v slow_closest))#pos pos) then 
	Printf.printf "We got a closest that is closer!!, radius %d\n" (!i - 1)
      else if (s#dist_coords (Nodes.node(o2v !closest))#pos pos >
      s#dist_coords (Nodes.node(o2v slow_closest))#pos pos) then 
	Printf.printf "We got a closest that is further, radius %d\n" (!i - 1);
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
	      if (s#dist_coords pos n#pos) < !closest_dist then (
		closest_id := Some n#id;
		closest_dist := (s#dist_coords pos n#pos)
	      )
	  | false -> ()
      );
    !closest_id
  )

  method get_nodes_within_radius  ~node ~radius = (
    
    let radius_sq = radius ** 2.0 in
    let center = node#pos in
    let l = ref [] in
    Nodes.iter (fun node -> if s#dist_coords center node#pos <= radius then l := (node#id)::!l) ;
    !l
  ) 

  method scale_unit f = f /. gridsize_

  method project_2d (x, y) =  (s#scale_unit x, s#scale_unit y)

  method get_node_at ~unitpos = 
    let scaleup = unitpos ***. gridsize_ in
    let (x,y) = (s#pos_in_grid_ scaleup) in
    o2v (s#find_closest ~pos:scaleup ~f:(fun _ -> true))


  method sprint_info () = Printf.sprintf "\tGridsize:\t\t\t %f\n" gridsize_

end


