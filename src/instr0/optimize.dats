
#include "share/atspre_staload.hats"
#include "share/atspre_define.hats"

staload "./../postiats/utfpl.sats"
staload "./../utils/utils.sats"
staload "./instr0.sats"

staload "libats/ML/SATS/basis.sats"
staload "libats/ML/SATS/list0.sats"

#define :: list0_cons
#define nil list0_nil
(* ************ ************* *)
local

staload _(*anon*) = "libats/ML/DATS/list0.dats"

in

extern fun i0optimize_tailcall_fundef (
  sa: stamp_allocator
  , i0fundef: i0fundef
  , funmap: i0funmap
): i0fundef

implement i0optimize_tailcall (sa, i0prog) = let
  val i0funmap = i0prog.i0prog_i0funmap

  // create a new map to hold newly generated functions
  val fmap = i0funmap_create (i2sz(2048))
  // 
  val funlist = 
    i0funmap_listize1 (i0funmap)

  val () = loop (funlist, fmap) where {
  fun loop (funlist: list0 (@(i0id, i0fundef))
            , fmap: i0funmap
           ): void = 
    case+ funlist of
    | list0_cons (funp, funlist1) => let
      val fundef = i0optimize_tailcall_fundef (sa, funp.1, i0funmap)
      val () = i0funmap_insert_any (fmap, funp.0, fundef)
    in
      loop (funlist1, fmap)
    end
    | list0_nil () => ()
  }
  
  val i0prog1 = '{
    i0prog_i0funmap = fmap
    , i0prog_i0gvarlst = i0prog.i0prog_i0gvarlst
  }
in
  i0prog1
end

implement i0optimize_tailcall_fundef (sa, i0fundef, i0funmap) = let
  val fnames = i0fundef_get_group (i0fundef)
  val fname = i0fundef_get_id (i0fundef)

  // grab all the parameters from all the functions
  val group_paralst = list0_foldleft<i0id><list0(i0id)> (
                fnames, list0_nil (), fopr) where {
  fun fopr (res: i0idlst, i0id: i0id):<cloref1> i0idlst = let
    val i0fundef = i0funmap_search0 (i0funmap, i0id)
    val paralst = i0fundef_get_paralst (i0fundef)
  in
    list0_append (res, paralst)
  end
  }

  // create new parameters for the current function
  typedef para_old_new = @(i0id (*variable*), i0id (*parameter*))
  val cur_paralst = i0fundef_get_paralst (i0fundef)
  val para_pair_lst = list0_foldleft<i0id><list0 para_old_new> (
                    cur_paralst, list0_nil, fopr) where {
    fun fopr (res: list0 para_old_new, i0id: i0id):<cloref1> list0 para_old_new = let
      val new_i0id = i0id_copy (i0id, sa)
      val res = list0_cons (@(i0id, new_i0id), res)
    in
      res
    end
  }
  
  // build an extra instruction for initialization
  val ins_init = INS0init_loop (group_paralst, para_pair_lst)


  // build tags for all the functions in the group
  // map function name to tag
  val map_fname_tag = i0idmap_create (i2sz(1024))
  val () = list0_foreach (fnames, fopr) where {
  fun fopr (i0id: i0id):<cloref1> void = let
    val new_id = i0id_copy (i0id, sa)
    val () = i0idmap_insert_any (map_fname_tag, i0id, new_id)
  in end
  }

  // transform current function
  val cur_inss = i0fundef_get_instructions (i0fundef)
  
  fun optimize_tailcall_return2jump (
    inss: i0inslst
    , map_fname_tag: i0idmap
    , i0funmap: i0funmap
  ): i0inslst = let
    fun loop (inss: i0inslst
              , accu: i0inslst): i0inslst =
    case+ inss of
    | list0_cons (ins, inss1) => let
      val ins' = transform_return2jump (ins)
      val accu' = list0_cons (ins', accu)
    in
      loop (inss1, accu')
    end
    | list0_nil () => list0_reverse (accu)
    // end of [loop]
    and
    transform_return2jump (
      ins: i0ins
    ): i0ins = case+ ins of
    | INS0decl (_) => ins
    | INS0assign (_, _) => ins
    | INS0label (_) => ins
    | INS0return (i0expopt) => 
      (case+ i0expopt of
      | Some0 i0exp => (case+ i0exp of
        | EXP0int _ => ins
        | EXP0i0nt _ => ins
        | EXP0var _ => ins
        | EXP0app (i0id, i0explst) => let
          val tag_id_opt = i0idmap_search (map_fname_tag, i0id)
        in
          case+ tag_id_opt of
          | ~Some_vt (tag_id) => let
            val i0fundef = i0funmap_search0 (i0funmap, i0id)
            val paralst = i0fundef_get_paralst (i0fundef)

            val para_pair_lst = list0_foldleft<i0id><list0 para_old_new> (
                              paralst, list0_nil, fopr) where {
              fun fopr (res: list0 para_old_new, i0id: i0id):<cloref1> list0 para_old_new = let
                val new_i0id = i0id_copy (i0id, sa)
                val res = list0_cons (@(i0id, new_i0id), res)
              in
                res
              end
            }
            val para_pair_lst = list0_reverse (para_pair_lst)

            val (calc_exp_lst, assign_lst) = loop (i0explst, para_pair_lst) where {
            fun loop (
              i0explst: i0explst
              , para_pair_lst: list0 para_old_new)
            : (i0inslst(*calc exp*), i0inslst (*assign var*)) = 
            case+ (i0explst, para_pair_lst) of
            | ((i0exp :: i0explst1), (para_pair :: para_pair_lst1)) => let
              val (inss1, inss2) = loop (i0explst1, para_pair_lst1)
              val ins1 = INS0assign (Some0 (para_pair.1), i0exp)
              val ins2 = INS0assign (Some0 (para_pair.0), EXP0var (para_pair.0))
              val inss1 = ins1 :: inss1
              val inss2 = ins2 :: inss2
            in (inss1, inss2) end
            | (nil (), nil ()) => (nil (), nil ())
            | (_, _) => exitlocmsg ("This shall not happen")
            }
            
            val ins = INS0tail_jump (list0_append (calc_exp_lst, assign_lst), tag_id)
          in
            ins
          end
          | ~None_vt () => ins
        end
        )
      | None0 () => ins
      )
    | INS0ifbranch (i0exp, i0inslst1 (*if*), i0inslst2 (*else*)) => let
      val i0inss3 = optimize_tailcall_return2jump (i0inslst1, map_fname_tag, i0funmap)
      val i0inss4 = optimize_tailcall_return2jump (i0inslst2, map_fname_tag, i0funmap)
    in
      INS0ifbranch (i0exp, i0inss3, i0inss4)
    end
    | INS0goto (_) => ins
    | INS0init_loop (_, _) => exitlocmsg ("Impossible.")
    | INS0tail_jump (_, _) => exitlocmsg ("Impossible.")

    val ret = loop (inss, list0_nil ())
  in
    ret
  end

  val new_inss = optimize_tailcall_return2jump (
    cur_inss, map_fname_tag, i0funmap)

  
  // todo

  // replace 
  
  // record the mapping from the old name to the new name

in
  i0fundef
end

  

end  // end of [local]
  
  
