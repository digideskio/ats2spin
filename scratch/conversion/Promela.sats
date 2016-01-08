(* ****** ****** *)
//
// For embedding
// Promela into ATS
//
(* ****** ****** *)
//
// Author: Hongwei Xi
// Authoremail: gmhwxiATgmailDOTcom
// Start time: December, 2015
//
(* ****** ****** *)
//
abstype
pid_type(i:int)
//
typedef
pid(i:int) = pid_type(i)
//
typedef pid = [i:nat] pid(i)
//
(* ****** ****** *)
//
fun
pid2int{i:nat}(pid(i)): int(i)

fun
int2pid{i:nat}(int(i)): pid(i)

fun 
pid_eq{i1,i2:nat}(pid(i1), pid(i2)): bool(i1 == i2)
//
(* ****** ****** *)
//
fun
Promela$mypid(): pid
//
fun
Promela$assert{b:bool}(bool(b)): [b==true] void
//
(* ****** ****** *)

fun
Promela$wait_until(() -> bool): void
fun
Promela$wait_unless(() -> bool): void
  
(* ****** ****** *)

(* end of [Promela.sats] *)
