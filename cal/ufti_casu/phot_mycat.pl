    %filterstruct = (
                     'J98' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Jmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'H98' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Hmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'K98' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Kmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'K98' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Kmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'Z' => {
                         'catalogue' => 'fs',
                         'refmag' => '$Zmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'I' => {
                         'catalogue' => 'fs',
                         'refmag' => '$Imag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'L98' => {
                         'catalogue' => 'fs',
                         'refmag' => '$Lmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'M98' => {
                         'catalogue' => 'fs',
                         'refmag' => '$Mmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     }
                    );
 
    %catalogues = (
                   '2mass' => {
                       'location' => "/home/jim/orac/testdata/out/cat.fit",
                       'accessmethod' => "searchfits",
                       'columns' => ['Jmag','Hmag','Kmag'],
                       'vars' => ['Jmag','Hmag','Kmag'],
                       'vizcat' => '2mass'
                    },
                   'fs' => {
                       'location' => "$ENV{ORAC_DATA_CAL}/fs_izjhklm.fit",
                       'accessmethod' => "searchfits",
                       'columns' => ['I','Z','J(98)','H(98)','K(98)','L(98)','M(98)'],
                       'vars' => ['Imag','Zmag','Jmag','Hmag','Kmag','Lmag','Mmag'],
                       'vizcat' => ''
                       }
                   );
 
