    %filterstruct = (
                     'J' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Jmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'H' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Hmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     },
                     'K' => {
                         'catalogue' => '2mass',
                         'refmag' => '$Kmag;',
                         'extinct' => '0.05*($airmass - 1.0);',
                         'zeropt' => 24.0,
                     }
                    );
 
    %catalogues = (
                   '2mass' => {
                       'location' => "viz2mass",
                       'accessmethod' => "searchinternet",
                       'columns' => ['Jmag','Hmag','Kmag'],
                       'vars' => ['Jmag','Hmag','Kmag'],
                       'vizcat' => 'viz2mass'
                       }
                  );

