(*

  Copyright (C) 2004 Swiss Federal Institute of Technology Lausanne (EPFL),
  Laboratory of Audiovisual Communications (LCAV) and 
  Laboratory for Computer Communications and Applications (LCA), 
  CH-1015 Lausanne, Switzerland

  Author: Henri Dubois-Ferriere 

  This file is part of mws (multihop wireless simulator).

  Mws is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  
  Mws is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with mws; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


*)







(** Layer 2 packet types and manipulators.
  
  @author Henri Dubois-Ferriere.
*)
open L3pkt

(** {2 L2 Packet Types} *)

type l2_dst_t = L2_BCAST | L2_DST of Common.nodeid_t
and l2hdr_t = { l2src : Common.nodeid_t; l2dst : l2_dst_t; }
type t = { l2hdr : l2hdr_t; l3pkt : L3pkt.t; }


(** {2 L2 Packet Constructors} *)

val clone_l2hdr : l2hdr:l2hdr_t -> l2hdr_t
val make_l2pkt :
  srcid:Common.nodeid_t -> l2_dst:l2_dst_t -> l3pkt:L3pkt.t -> t
val clone_l2pkt : l2pkt:t -> t



(** {2 L2 Packet Deconstructors} *)

val l3pkt : l2pkt:t -> L3pkt.t
val l2hdr : pkt:t -> l2hdr_t
val l2src : pkt:t -> Common.nodeid_t
val l2dst : pkt:t -> l2_dst_t
val string_of_l2dst : l2_dst_t -> string

(** {2 Packet Sizes} *)

val l2hdr_size : int
val l2pkt_size : l2pkt:t -> int
