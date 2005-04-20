    %filterstruct = (
                     'J' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Jmag - 0.1*($Jmag - $Hmag);',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'H' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Hmag + 0.15*($Jmag - $Hmag);',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'K' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Kmag - 0.05*($Jmag - $Kmag);',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
		     'Z' => {
			 'catalogue' => '2mass',
			 'refmag' => '$Jmag + 0.9*($Jmag - $Hmag);',
			 'extinct' => '0.05*($airmass - 1.0);',
			 'zeropt' => 24.0,
		     },
		     'Y' => {
			 'catalogue' => '2mass',
			 'refmag' => '$Jmag + 0.4*($Jmag - $Hmag);',
			 'extinct' => '0.05*($airmass - 1.0);',
			 'zeropt' => 24.0,
		     }
                    );
 
    %catalogues = (
                   '2mass' => {
                       'location' => "/scratch/jim/2mass",
                       'accessmethod' => "searchinternet",
                       'columns' => ['Jmag','Hmag','Kmag'],
                       'vars' => ['Jmag','Hmag','Kmag'],
                       'vizcat' => 'viz2mass'
                       },
                   'fs' => {
		       'location'=>"$ENV{'ORAC_DATA_CAL'}/fs_izjhklm.fit",
		       'accessmethod' => "searchfits",
		       'columns' => ['imag','zmag'],
		       'vars' => ['imag','zmag'],
                       'vizcat' => ""
		       }
                  );

