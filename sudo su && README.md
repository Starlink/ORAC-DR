sudo su && [![DOI](https://zenodo.org/badge/12517/Starlink/ORAC-DR.svg)](http://dx.doi.org/10.5281/zenodo.17214)

This is the ORAC Data Reduction pipeline software (ORAC-DR)

You can use it to reduce astronomical data from the James Clerk Maxwell Telescope, the United Kingdom Infrared Telescope, the Anglo-Australian Telescope and the Las Cumbres Observatory.

The directories are laid out as follows:

```
  src/        Source code tree
      bin        Executables
      etc        Initialisation scripts
      lib        Infrastructure code
      recipes    Per-instrument data reduction high level recipes
      primitives Per-instrument data reduction low level control code
      admin      Pre-processing support scripts
      cgi        Web interfaces
      docs       Documentation
      gui        GUI definition files
      images     Support images
      t          Infrastructure tests
      uml        Class layouts (currently out of date)

  cal/      Calibration support files per instrument
```

The check out repository can be used directly so long as the following
environment variables are set

* `ORAC_DIR`       Set to the `src` directory
* `ORAC_PERL5LIB`  Set to the `src/lib/perl5` directory
* `ORAC_PERLBIN`   Set to a suitable perl binary
* `ORAC_CAL_ROOT`  Set to the `cal` directory

and then source the `src/etc/login` and `src/etc/cshrc` (or profile) scripts.
