#!/home/timj/data/bin/perl

use Starlink::ADAMTASK;
use Starlink::NBS;	      

adamtask_init;
	
# load p4

$ENV{P4_CT} = $ENV{CGS4DR_ROOT}."/ndf";
$ENV{P4_CONFIG} = $ENV{HOME}."/cgs4dr_configs";

$p4 = new Starlink::ADAMTASK ("p4","/star/bin/cgs4dr/p4");
$p4->set("noticeboard","p4_nb");
print "Noticeboar set to ",$p4->get("noticeboard");
$p4->obeyw("open_nb");

$nbs = new Starlink::ADAMTASK ("p4_nb");

$p4->obeyw("close_nb");
adamtask_exit;
