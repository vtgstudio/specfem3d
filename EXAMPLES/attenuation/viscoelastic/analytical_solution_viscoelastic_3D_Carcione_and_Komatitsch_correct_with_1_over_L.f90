
  program analytical_solution

! This program implements the analytical solution for the displacement vector in a 3D viscoelastic medium
! with a vertical force source located in (0,0,0).
! Implemented by Dimitri Komatitsch from the 2D plane-strain viscoelastic medium analytical solution
! of Appendix B of Carcione et al., Wave propagation simulation in a linear viscoelastic medium, GJI, vol. 95, p. 597-611 (1988)
! (note that that Appendix contains two typos, fixed in this code).
! The amplitude of the force is called F and is defined below.

!! DK DK Dimitri Komatitsch, CNRS Marseille, France, May 2018.

  implicit none

!! DK DK May 2018: the missing 1/L factor in older Carcione papers
!! DK DK May 2018: has been added to this code by Quentin Brissaud and by Etienne Bachmann
!! DK DK for the viscoacoustic code in directory EXAMPLES/attenuation/viscoacoustic,
!! DK DK it would be very easy to copy the changes from there to this viscoelastic version;
!! DK DK but then all the values of the tau_epsilon in the code below would need to change.

!! DK DK Dimitri Komatitsch, CNRS Marseille, France, April 2017: added the elastic reference calculation.

! compute the elastic solution instead of the viscoelastic one,
! i.e. turn off viscoelasticity and compute the elastic Green function instead
  logical, parameter :: COMPUTE_ELASTIC_CASE_INSTEAD = .false.

! to see how small the contribution of the near-field term is,
! here the user can ask not to include it, to then compare with the full result obtained with this flag set to false
  logical, parameter :: DO_NOT_COMPUTE_THE_NEAR_FIELD = .false.

  integer, parameter :: iratio = 32

  integer, parameter :: nfreq = 524288
  integer, parameter :: nt = iratio * nfreq

  double precision, parameter :: freqmax = 80.d0
!! DK DK to print the velocity if we want to display the curve of how velocity varies with frequency
!! DK DK for instance to compute the unrelaxed velocity in the Zener model
! double precision, parameter :: freqmax = 20000.d0

  double precision, parameter :: freqseuil = 0.00005d0

  double precision, parameter :: pi = 3.141592653589793d0

! for the solution in time domain
  integer it,i
  real wsave(4*nt+15)
  complex c(nt)

! density of the medium
  double precision, parameter :: rho = 2000.d0

! unrelaxed (f = +infinity) values
! these values for the unrelaxed state are computed from the relaxed state values (Vp = 3000, Vs = 2000, rho = 2000)
! given in Carcione et al. 1988 GJI vol 95 p 604 Table 1
  double precision, parameter :: Vp = 3297.849d0
  double precision, parameter :: Vs = 2222.536d0

! unrelaxed (f = +infinity) values, i.e. using the fastest Vp and Vs velocities
  double precision, parameter :: M2_unrelaxed = Vs**2 * 2.d0 * rho
  double precision, parameter :: M1_unrelaxed = 2.d0 * Vp**2 * rho - M2_unrelaxed

! amplitude of the force source
  double precision, parameter :: F = 1.d0

! spatial dimension of the problem (this analytical code is valid only in three dimensions, thus do not change this)
  integer, parameter :: NDIM = 3

! definition position recepteur Carcione
  double precision, dimension(NDIM) :: x

! Definition source Dimitri
  double precision, parameter :: f0 = 18.d0
  double precision, parameter :: t0 = 1.2d0 / f0

! Definition source Carcione
! double precision f0,t0,eta,epsil
! parameter(f0 = 50.d0)
! parameter(t0 = 0.075d0)
! parameter(epsil = 1.d0)
! parameter(eta = 0.5d0)

! number of Zener standard linear solids in parallel
  integer, parameter :: Lnu = 3

! attenuation relaxation times
  double precision tau_epsilon_nu1_mech1, tau_sigma_nu1_mech1, tau_epsilon_nu2_mech1, tau_sigma_nu2_mech1, &
    tau_epsilon_nu1_mech2, tau_sigma_nu1_mech2, tau_epsilon_nu2_mech2, tau_sigma_nu2_mech2

!! DK DK March 2018: this missing 1/L factor has been added to this code by Quentin Brissaud
!! DK DK for the viscoacoustic code in directory EXAMPLES/attenuation/viscoacoustic,
!! DK DK it would be very easy to copy the changes from there to this viscoelastic version;
!! DK DK but then all the values of the tau_epsilon below would need to change.

 double precision, dimension(Lnu) :: tau_sigma_nu1,tau_sigma_nu2,tau_epsilon_nu1,tau_epsilon_nu2

  integer :: ifreq,ifreq2
  double precision :: deltafreq,freq,omega,omega0,deltat,time
  double complex :: comparg

! Fourier transform of the Ricker wavelet source
  double complex fomega(0:nfreq)

! real and imaginary parts
  double precision ra(0:nfreq),rb(0:nfreq)

! spectral amplitude
  double precision ampli(0:nfreq)

! analytical solution for the three components
  double complex phi1(-nfreq:nfreq)
  double complex phi2(-nfreq:nfreq)
  double complex phi3(-nfreq:nfreq)

! external function
  double complex, external :: ui

! modules elastiques
  double complex :: M1C, M2C, E, V1, V2, temp

! ********** end of variable declarations ************

! classical least-squares constants
 tau_epsilon_nu1 =  (/ 0.109527114743452     ,  1.070028707488438E-002,  1.132519034287800E-003/)
 tau_sigma_nu1 = (/  8.841941282883074E-002 , 8.841941282883075E-003,  8.841941282883074E-004/)
 tau_epsilon_nu2 = (/  0.112028084581976    ,   1.093882462934487E-002,  1.167173427475064E-003/)
 tau_sigma_nu2 = (/  8.841941282883074E-002,  8.841941282883075E-003,  8.841941282883074E-004/)

! position of the receiver
  x(1) = +500.
  x(2) = +500.
  x(3) = +500.

  print *,'Force source located at the origin (0,0,0)'
  print *,'Receiver located in (x,y,z) = ',x(1),x(2),x(3)

  if (COMPUTE_ELASTIC_CASE_INSTEAD) then
    print *,'BEWARE: computing the elastic reference solution (i.e., without attenuation) instead of the viscoelastic solution'
  else
    print *,'Computing the viscoelastic solution'
  endif

  if (DO_NOT_COMPUTE_THE_NEAR_FIELD) then
    print *,'BEWARE: computing the far-field solution only, rather than the full Green function'
  else
    print *,'Computing the full solution, including the near-field term of the Green function'
  endif

! step in frequency
  deltafreq = freqmax / dble(nfreq)

! define the spectrum of the source
  do ifreq=0,nfreq
      freq = deltafreq * dble(ifreq)
      omega = 2.d0 * pi * freq
      omega0 = 2.d0 * pi * f0
! typo in equation (B7) of Carcione et al., Wave propagation simulation in a linear viscoelastic medium,
! Geophysical Journal, vol. 95, p. 597-611 (1988), the exponential should be of -i omega t0,
! fixed here by adding the minus sign
      comparg = dcmplx(0.d0,-omega*t0)

! definir le spectre du Ricker de Carcione avec cos()
! equation (B7) of Carcione et al., Wave propagation simulation in a linear viscoelastic medium,
! Geophysical Journal, vol. 95, p. 597-611 (1988)
!     fomega(ifreq) = pi * dsqrt(pi/eta) * (1.d0/omega0) * cdexp(comparg) * ( dexp(- (pi*pi/eta) * (epsil/2 - omega/omega0)**2) &
!         + dexp(- (pi*pi/eta) * (epsil/2 + omega/omega0)**2) )

! definir le spectre d'un Ricker classique
      fomega(ifreq) = - omega**2 * 2.d0 * (dsqrt(pi)/omega0) * cdexp(comparg) * dexp(- (omega/omega0)**2)

      ra(ifreq) = dreal(fomega(ifreq))
      rb(ifreq) = dimag(fomega(ifreq))
! prendre le module de l'amplitude spectrale
      ampli(ifreq) = dsqrt(ra(ifreq)**2 + rb(ifreq)**2)
  enddo

! sauvegarde du spectre d'amplitude de la source en Hz au format Gnuplot
  open(unit=10,file='spectrum.gnu',status='unknown')
  do ifreq = 0,nfreq
      freq = deltafreq * dble(ifreq)
      write(10,*) sngl(freq),sngl(ampli(ifreq))
  enddo
  close(10)

! ************** calcul solution analytique ****************

! d'apres Carcione GJI vol 95 p 611 (1988)
  do ifreq=0,nfreq
      freq = deltafreq * dble(ifreq)
      omega = 2.d0 * pi * freq

! critere ad-hoc pour eviter singularite en zero
  if (freq < freqseuil) omega = 2.d0 * pi * freqseuil

! use standard infinite frequency (unrelaxed) reference,
! in which waves slow down when attenuation is turned on.
  temp = dcmplx(0.d0,0.d0)
  do i=1,Lnu
    temp = temp + dcmplx(1.d0,omega*tau_epsilon_nu1(i)) / dcmplx(1.d0,omega*tau_sigma_nu1(i))
  enddo

  M1C = (M1_unrelaxed /(sum(tau_epsilon_nu1(:)/tau_sigma_nu1(:)))) * temp

  temp = dcmplx(0.d0,0.d0)
  do i=1,Lnu
    temp = temp + dcmplx(1.d0,omega*tau_epsilon_nu2(i)) / dcmplx(1.d0,omega*tau_sigma_nu2(i))
  enddo

  M2C = (M2_unrelaxed /(sum(tau_epsilon_nu2(:)/tau_sigma_nu2(:)))) * temp

  if (COMPUTE_ELASTIC_CASE_INSTEAD) then
! from Etienne Bachmann, May 2018: pour calculer la solution sans attenuation, il faut donner le Mu_unrelaxed et pas le Mu_relaxed.
! En effet, pour comparer avec SPECFEM, il faut simplement partir de la bonne reference.
! SPECFEM est defini en unrelaxed et les constantes unrelaxed dans Carcione matchent parfaitement les Vp et Vs definis dans SPECFEM.
    M1C = M1_unrelaxed
    M2C = M2_unrelaxed
  endif

  E = (M1C + M2C) / 2
  V1 = cdsqrt(E / rho)  !! DK DK this is Vp
!! DK DK print the velocity if we want to display the curve of how velocity varies with frequency
!! DK DK for instance to compute the unrelaxed velocity in the Zener model
! print *,freq,dsqrt(real(V1)**2 + imag(V1)**2)
  V2 = cdsqrt(M2C / (2.d0 * rho))  !! DK DK this is Vs
!! DK DK print the velocity if we want to display the curve of how velocity varies with frequency
!! DK DK for instance to compute the unrelaxed velocity in the Zener model
! print *,freq,dsqrt(real(V2)**2 + imag(V2)**2)

! calcul de la solution analytique en frequence
  phi1(ifreq) = ui(1,omega,V1,V2,x,rho,NDIM,F,DO_NOT_COMPUTE_THE_NEAR_FIELD) * fomega(ifreq)
  phi2(ifreq) = ui(2,omega,V1,V2,x,rho,NDIM,F,DO_NOT_COMPUTE_THE_NEAR_FIELD) * fomega(ifreq)
  phi3(ifreq) = ui(3,omega,V1,V2,x,rho,NDIM,F,DO_NOT_COMPUTE_THE_NEAR_FIELD) * fomega(ifreq)

  enddo

! take the conjugate value for negative frequencies
  do ifreq=-nfreq,-1
      phi1(ifreq) = dconjg(phi1(-ifreq))
      phi2(ifreq) = dconjg(phi2(-ifreq))
      phi3(ifreq) = dconjg(phi3(-ifreq))
  enddo

! ***************************************************************************
! Calculation of the time domain solution (using routine "cfftb" from Netlib)
! ***************************************************************************

! **********
! Compute Ux
! **********

! initialize FFT arrays
  call cffti(nt,wsave)

! clear array of Fourier coefficients
  do it=1,nt
      c(it) = cmplx(0.,0.)
  enddo

! use the Fourier values for Ux
  c(1) = cmplx(phi1(0))
  do ifreq=1,nfreq-2
      c(ifreq+1) = cmplx(phi1(ifreq))
      c(nt+1-ifreq) = conjg(cmplx(phi1(ifreq)))
  enddo

! perform the inverse FFT for Ux
  call cfftb(nt,c,wsave)

! value of a time step
  deltat = 1.d0 / (freqmax*dble(iratio))

! save time result inverse FFT for Ux

  if (COMPUTE_ELASTIC_CASE_INSTEAD) then
    open(unit=11,file='Ux_time_analytical_solution_elastic.dat',status='unknown')
  else
    if (DO_NOT_COMPUTE_THE_NEAR_FIELD) then
      open(unit=11,file='Ux_time_analytical_solution_viscoelastic_without_near_field.dat',status='unknown')
    else
      open(unit=11,file='Ux_time_analytical_solution_viscoelastic.dat',status='unknown')
    endif
  endif
  do it=1,nt
! DK DK Dec 2011: subtract t0 to be consistent with the SPECFEM2D code
        time = dble(it)*deltat - t0
! the seismograms are very long due to the very large number of FFT points used,
! thus keeping the useful part of the signal only (the first six seconds of the seismogram)
        if (time <= 6.d0) write(11,*) sngl(time),real(c(it))
  enddo
  close(11)

! **********
! Compute Uy
! **********

! clear array of Fourier coefficients
  do it=1,nt
      c(it) = cmplx(0.,0.)
  enddo

! use the Fourier values for Uy
  c(1) = cmplx(phi2(0))
  do ifreq=1,nfreq-2
      c(ifreq+1) = cmplx(phi2(ifreq))
      c(nt+1-ifreq) = conjg(cmplx(phi2(ifreq)))
  enddo

! perform the inverse FFT for Uy
  call cfftb(nt,c,wsave)

! save time result inverse FFT for Uy
  if (COMPUTE_ELASTIC_CASE_INSTEAD) then
    open(unit=11,file='Uy_time_analytical_solution_elastic.dat',status='unknown')
  else
    if (DO_NOT_COMPUTE_THE_NEAR_FIELD) then
      open(unit=11,file='Uy_time_analytical_solution_viscoelastic_without_near_field.dat',status='unknown')
    else
      open(unit=11,file='Uy_time_analytical_solution_viscoelastic.dat',status='unknown')
    endif
  endif
  do it=1,nt
! DK DK Dec 2011: subtract t0 to be consistent with the SPECFEM2D code
        time = dble(it)*deltat - t0
! the seismograms are very long due to the very large number of FFT points used,
! thus keeping the useful part of the signal only (the first six seconds of the seismogram)
        if (time <= 6.d0) write(11,*) sngl(time),real(c(it))
  enddo
  close(11)

! **********
! Compute Uz
! **********

! clear array of Fourier coefficients
  do it=1,nt
      c(it) = cmplx(0.,0.)
  enddo

! use the Fourier values for Uz
  c(1) = cmplx(phi3(0))
  do ifreq=1,nfreq-2
      c(ifreq+1) = cmplx(phi3(ifreq))
      c(nt+1-ifreq) = conjg(cmplx(phi3(ifreq)))
  enddo

! perform the inverse FFT for Uz
  call cfftb(nt,c,wsave)

! save time result inverse FFT for Uz
  if (COMPUTE_ELASTIC_CASE_INSTEAD) then
    open(unit=11,file='Uz_time_analytical_solution_elastic.dat',status='unknown')
  else
    if (DO_NOT_COMPUTE_THE_NEAR_FIELD) then
      open(unit=11,file='Uz_time_analytical_solution_viscoelastic_without_near_field.dat',status='unknown')
    else
      open(unit=11,file='Uz_time_analytical_solution_viscoelastic.dat',status='unknown')
    endif
  endif
  do it=1,nt
! DK DK Dec 2011: subtract t0 to be consistent with the SPECFEM2D code
        time = dble(it)*deltat - t0
! the seismograms are very long due to the very large number of FFT points used,
! thus keeping the useful part of the signal only (the first six seconds of the seismogram)
        if (time <= 6.d0) write(11,*) sngl(time),real(c(it))
  enddo
  close(11)

  end

! -----------

  double complex function ui(i,omega,v1,v2,x,rho,NDIM,F,DO_NOT_COMPUTE_THE_NEAR_FIELD)

  implicit none

  double precision, parameter :: pi = 3.141592653589793d0

  integer i,j
  double precision omega,F
  double complex :: v1,v2,Up_far_field,Us_far_field,near_field,i_imaginary_constant
  double complex :: fourier_transform_of_Heaviside_times_t_for_Vp,fourier_transform_of_Heaviside_times_t_for_Vs
  logical :: DO_NOT_COMPUTE_THE_NEAR_FIELD

  integer :: NDIM,kronecker_delta_symbol
  double precision, dimension(NDIM) :: x,gamma_vector
  double precision :: r,rho

! source-receiver distance
  r = dsqrt(x(1)**2 + x(2)**2 + x(3)**2)

! define the gamma vector of Aki and Richards (1980), which is the unit vector from the source to the receiver
! see Aki and Richards (1980) below Box 4.3 (continued) and above equation (4.23)
  gamma_vector(:) = x(:) / r

! the force is vertical in this analytical code, thus the j direction of the force is Z
  j = 3

! imaginary constant "i"
  i_imaginary_constant = (0.d0,1.d0)

! Kronecker delta symbol
  if (i == j) then
    kronecker_delta_symbol = 1
  else
    kronecker_delta_symbol = 0
  endif

! far-field P wave term
! see e.g. Aki and Richards (1980), equation (4.24) in the time domain; here we use the same equation but in the frequency domain
  Up_far_field = gamma_vector(i) * gamma_vector(j) * exp(-i_imaginary_constant*omega*r/v1) / (4.d0 * pi * rho * v1**2 * r)

! far-field S wave term
! see e.g. Aki and Richards (1980), equation (4.25) in the time domain; here we use the same equation but in the frequency domain
! note that Aki and Richards (1980) has a typo in equation (4.25), a term 1/r is missing; fixed here.
! The corrected equation is for instance in Jose Pujol, Elastic wave propagation and generation in seismology, equation (9.6.1)
  Us_far_field = (kronecker_delta_symbol - gamma_vector(i) * gamma_vector(j)) * exp(-i_imaginary_constant*omega*r/v2) &
               / (4.d0 * pi * rho * v2**2 * r)

! near field term (see e.g. Jose Pujol, Elastic wave propagation and generation in seismology, equation (9.6.1) in the time domain;
! here we use the same equation but in the frequency domain)
  fourier_transform_of_Heaviside_times_t_for_Vp = i_imaginary_constant * (-omega*r + i_imaginary_constant*v1) * &
                   exp(-i_imaginary_constant*omega*r/v1) / (v1 * omega**2)

  fourier_transform_of_Heaviside_times_t_for_Vs = i_imaginary_constant * (-omega*r + i_imaginary_constant*v2) * &
                   exp(-i_imaginary_constant*omega*r/v2) / (v2 * omega**2)

  near_field = (3 * gamma_vector(i) * gamma_vector(j) - kronecker_delta_symbol) * &
     (fourier_transform_of_Heaviside_times_t_for_Vp - fourier_transform_of_Heaviside_times_t_for_Vs) / (4.d0 * pi * rho * r**3)

  if (DO_NOT_COMPUTE_THE_NEAR_FIELD) near_field = dcmplx(0.d0,0.d0)

! the result is the sum of the three terms; we also multiply by the amplitude of the force
  ui = F * (Up_far_field + Us_far_field + near_field)

  end

! ***************** routine de FFT pour signal en temps ****************

! FFT routine taken from Netlib

  subroutine CFFTB (N,C,WSAVE)
  DIMENSION       C(1)       ,WSAVE(1)
  if (N == 1) return
  IW1 = N+N+1
  IW2 = IW1+N+N
  CALL CFFTB1 (N,C,WSAVE,WSAVE(IW1),WSAVE(IW2))
  return
  END
  subroutine CFFTB1 (N,C,CH,WA,IFAC)
  DIMENSION       CH(1)      ,C(1)       ,WA(1)      ,IFAC(1)
  NF = IFAC(2)
  NA = 0
  L1 = 1
  IW = 1
  DO 116 K1=1,NF
   IP = IFAC(K1+2)
   L2 = IP*L1
   IDO = N/L2
   IDOT = IDO+IDO
   IDL1 = IDOT*L1
   if (IP /= 4) goto 103
   IX2 = IW+IDOT
   IX3 = IX2+IDOT
   if (NA /= 0) goto 101
   CALL PASSB4 (IDOT,L1,C,CH,WA(IW),WA(IX2),WA(IX3))
   goto 102
  101    CALL PASSB4 (IDOT,L1,CH,C,WA(IW),WA(IX2),WA(IX3))
  102    NA = 1-NA
   goto 115
  103    if (IP /= 2) goto 106
   if (NA /= 0) goto 104
   CALL PASSB2 (IDOT,L1,C,CH,WA(IW))
   goto 105
  104    CALL PASSB2 (IDOT,L1,CH,C,WA(IW))
  105    NA = 1-NA
   goto 115
  106    if (IP /= 3) goto 109
   IX2 = IW+IDOT
   if (NA /= 0) goto 107
   CALL PASSB3 (IDOT,L1,C,CH,WA(IW),WA(IX2))
   goto 108
  107    CALL PASSB3 (IDOT,L1,CH,C,WA(IW),WA(IX2))
  108    NA = 1-NA
   goto 115
  109    if (IP /= 5) goto 112
   IX2 = IW+IDOT
   IX3 = IX2+IDOT
   IX4 = IX3+IDOT
   if (NA /= 0) goto 110
   CALL PASSB5 (IDOT,L1,C,CH,WA(IW),WA(IX2),WA(IX3),WA(IX4))
   goto 111
  110    CALL PASSB5 (IDOT,L1,CH,C,WA(IW),WA(IX2),WA(IX3),WA(IX4))
  111    NA = 1-NA
   goto 115
  112    if (NA /= 0) goto 113
   CALL PASSB (NAC,IDOT,IP,L1,IDL1,C,C,C,CH,CH,WA(IW))
   goto 114
  113    CALL PASSB (NAC,IDOT,IP,L1,IDL1,CH,CH,CH,C,C,WA(IW))
  114    if (NAC /= 0) NA = 1-NA
  115    L1 = L2
   IW = IW+(IP-1)*IDOT
  116 continue
  if (NA == 0) return
  N2 = N+N
  DO 117 I=1,N2
   C(I) = CH(I)
  117 continue
  return
  END
  subroutine PASSB (NAC,IDO,IP,L1,IDL1,CC,C1,C2,CH,CH2,WA)
  DIMENSION       CH(IDO,L1,IP)          ,CC(IDO,IP,L1), &
                  C1(IDO,L1,IP)          ,WA(1)      ,C2(IDL1,IP), &
                  CH2(IDL1,IP)
  IDOT = IDO/2
  NT = IP*IDL1
  IPP2 = IP+2
  IPPH = (IP+1)/2
  IDP = IP*IDO
!
  if (IDO < L1) goto 106
  DO 103 J=2,IPPH
   JC = IPP2-J
   DO 102 K=1,L1
      DO 101 I=1,IDO
         CH(I,K,J) = CC(I,J,K)+CC(I,JC,K)
         CH(I,K,JC) = CC(I,J,K)-CC(I,JC,K)
  101       continue
  102    continue
  103 continue
  DO 105 K=1,L1
   DO 104 I=1,IDO
      CH(I,K,1) = CC(I,1,K)
  104    continue
  105 continue
  goto 112
  106 DO 109 J=2,IPPH
   JC = IPP2-J
   DO 108 I=1,IDO
      DO 107 K=1,L1
         CH(I,K,J) = CC(I,J,K)+CC(I,JC,K)
         CH(I,K,JC) = CC(I,J,K)-CC(I,JC,K)
  107       continue
  108    continue
  109 continue
  DO 111 I=1,IDO
   DO 110 K=1,L1
      CH(I,K,1) = CC(I,1,K)
  110    continue
  111 continue
  112 IDL = 2-IDO
  INC = 0
  DO 116 L=2,IPPH
   LC = IPP2-L
   IDL = IDL+IDO
   DO 113 IK=1,IDL1
      C2(IK,L) = CH2(IK,1)+WA(IDL-1)*CH2(IK,2)
      C2(IK,LC) = WA(IDL)*CH2(IK,IP)
  113    continue
   IDLJ = IDL
   INC = INC+IDO
   DO 115 J=3,IPPH
      JC = IPP2-J
      IDLJ = IDLJ+INC
      if (IDLJ > IDP) IDLJ = IDLJ-IDP
      WAR = WA(IDLJ-1)
      WAI = WA(IDLJ)
      DO 114 IK=1,IDL1
         C2(IK,L) = C2(IK,L)+WAR*CH2(IK,J)
         C2(IK,LC) = C2(IK,LC)+WAI*CH2(IK,JC)
  114       continue
  115    continue
  116 continue
  DO 118 J=2,IPPH
   DO 117 IK=1,IDL1
      CH2(IK,1) = CH2(IK,1)+CH2(IK,J)
  117    continue
  118 continue
  DO 120 J=2,IPPH
   JC = IPP2-J
   DO 119 IK=2,IDL1,2
      CH2(IK-1,J) = C2(IK-1,J)-C2(IK,JC)
      CH2(IK-1,JC) = C2(IK-1,J)+C2(IK,JC)
      CH2(IK,J) = C2(IK,J)+C2(IK-1,JC)
      CH2(IK,JC) = C2(IK,J)-C2(IK-1,JC)
  119    continue
  120 continue
  NAC = 1
  if (IDO == 2) return
  NAC = 0
  DO 121 IK=1,IDL1
   C2(IK,1) = CH2(IK,1)
  121 continue
  DO 123 J=2,IP
   DO 122 K=1,L1
      C1(1,K,J) = CH(1,K,J)
      C1(2,K,J) = CH(2,K,J)
  122    continue
  123 continue
  if (IDOT > L1) goto 127
  IDIJ = 0
  DO 126 J=2,IP
   IDIJ = IDIJ+2
   DO 125 I=4,IDO,2
      IDIJ = IDIJ+2
      DO 124 K=1,L1
         C1(I-1,K,J) = WA(IDIJ-1)*CH(I-1,K,J)-WA(IDIJ)*CH(I,K,J)
         C1(I,K,J) = WA(IDIJ-1)*CH(I,K,J)+WA(IDIJ)*CH(I-1,K,J)
  124       continue
  125    continue
  126 continue
  return
  127 IDJ = 2-IDO
  DO 130 J=2,IP
   IDJ = IDJ+IDO
   DO 129 K=1,L1
      IDIJ = IDJ
      DO 128 I=4,IDO,2
         IDIJ = IDIJ+2
         C1(I-1,K,J) = WA(IDIJ-1)*CH(I-1,K,J)-WA(IDIJ)*CH(I,K,J)
         C1(I,K,J) = WA(IDIJ-1)*CH(I,K,J)+WA(IDIJ)*CH(I-1,K,J)
  128       continue
  129    continue
  130 continue
  return
  END
  subroutine PASSB2 (IDO,L1,CC,CH,WA1)
  DIMENSION       CC(IDO,2,L1)           ,CH(IDO,L1,2), &
                  WA1(1)
  if (IDO > 2) goto 102
  DO 101 K=1,L1
   CH(1,K,1) = CC(1,1,K)+CC(1,2,K)
   CH(1,K,2) = CC(1,1,K)-CC(1,2,K)
   CH(2,K,1) = CC(2,1,K)+CC(2,2,K)
   CH(2,K,2) = CC(2,1,K)-CC(2,2,K)
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      CH(I-1,K,1) = CC(I-1,1,K)+CC(I-1,2,K)
      TR2 = CC(I-1,1,K)-CC(I-1,2,K)
      CH(I,K,1) = CC(I,1,K)+CC(I,2,K)
      TI2 = CC(I,1,K)-CC(I,2,K)
      CH(I,K,2) = WA1(I-1)*TI2+WA1(I)*TR2
      CH(I-1,K,2) = WA1(I-1)*TR2-WA1(I)*TI2
  103    continue
  104 continue
  return
  END
  subroutine PASSB3 (IDO,L1,CC,CH,WA1,WA2)
  DIMENSION       CC(IDO,3,L1)           ,CH(IDO,L1,3), &
                  WA1(1)     ,WA2(1)
  DATA TAUR,TAUI /-.5,.866025403784439/
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TR2 = CC(1,2,K)+CC(1,3,K)
   CR2 = CC(1,1,K)+TAUR*TR2
   CH(1,K,1) = CC(1,1,K)+TR2
   TI2 = CC(2,2,K)+CC(2,3,K)
   CI2 = CC(2,1,K)+TAUR*TI2
   CH(2,K,1) = CC(2,1,K)+TI2
   CR3 = TAUI*(CC(1,2,K)-CC(1,3,K))
   CI3 = TAUI*(CC(2,2,K)-CC(2,3,K))
   CH(1,K,2) = CR2-CI3
   CH(1,K,3) = CR2+CI3
   CH(2,K,2) = CI2+CR3
   CH(2,K,3) = CI2-CR3
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TR2 = CC(I-1,2,K)+CC(I-1,3,K)
      CR2 = CC(I-1,1,K)+TAUR*TR2
      CH(I-1,K,1) = CC(I-1,1,K)+TR2
      TI2 = CC(I,2,K)+CC(I,3,K)
      CI2 = CC(I,1,K)+TAUR*TI2
      CH(I,K,1) = CC(I,1,K)+TI2
      CR3 = TAUI*(CC(I-1,2,K)-CC(I-1,3,K))
      CI3 = TAUI*(CC(I,2,K)-CC(I,3,K))
      DR2 = CR2-CI3
      DR3 = CR2+CI3
      DI2 = CI2+CR3
      DI3 = CI2-CR3
      CH(I,K,2) = WA1(I-1)*DI2+WA1(I)*DR2
      CH(I-1,K,2) = WA1(I-1)*DR2-WA1(I)*DI2
      CH(I,K,3) = WA2(I-1)*DI3+WA2(I)*DR3
      CH(I-1,K,3) = WA2(I-1)*DR3-WA2(I)*DI3
  103    continue
  104 continue
  return
  END
  subroutine PASSB4 (IDO,L1,CC,CH,WA1,WA2,WA3)
  DIMENSION       CC(IDO,4,L1)           ,CH(IDO,L1,4), &
                  WA1(1)     ,WA2(1)     ,WA3(1)
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TI1 = CC(2,1,K)-CC(2,3,K)
   TI2 = CC(2,1,K)+CC(2,3,K)
   TR4 = CC(2,4,K)-CC(2,2,K)
   TI3 = CC(2,2,K)+CC(2,4,K)
   TR1 = CC(1,1,K)-CC(1,3,K)
   TR2 = CC(1,1,K)+CC(1,3,K)
   TI4 = CC(1,2,K)-CC(1,4,K)
   TR3 = CC(1,2,K)+CC(1,4,K)
   CH(1,K,1) = TR2+TR3
   CH(1,K,3) = TR2-TR3
   CH(2,K,1) = TI2+TI3
   CH(2,K,3) = TI2-TI3
   CH(1,K,2) = TR1+TR4
   CH(1,K,4) = TR1-TR4
   CH(2,K,2) = TI1+TI4
   CH(2,K,4) = TI1-TI4
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TI1 = CC(I,1,K)-CC(I,3,K)
      TI2 = CC(I,1,K)+CC(I,3,K)
      TI3 = CC(I,2,K)+CC(I,4,K)
      TR4 = CC(I,4,K)-CC(I,2,K)
      TR1 = CC(I-1,1,K)-CC(I-1,3,K)
      TR2 = CC(I-1,1,K)+CC(I-1,3,K)
      TI4 = CC(I-1,2,K)-CC(I-1,4,K)
      TR3 = CC(I-1,2,K)+CC(I-1,4,K)
      CH(I-1,K,1) = TR2+TR3
      CR3 = TR2-TR3
      CH(I,K,1) = TI2+TI3
      CI3 = TI2-TI3
      CR2 = TR1+TR4
      CR4 = TR1-TR4
      CI2 = TI1+TI4
      CI4 = TI1-TI4
      CH(I-1,K,2) = WA1(I-1)*CR2-WA1(I)*CI2
      CH(I,K,2) = WA1(I-1)*CI2+WA1(I)*CR2
      CH(I-1,K,3) = WA2(I-1)*CR3-WA2(I)*CI3
      CH(I,K,3) = WA2(I-1)*CI3+WA2(I)*CR3
      CH(I-1,K,4) = WA3(I-1)*CR4-WA3(I)*CI4
      CH(I,K,4) = WA3(I-1)*CI4+WA3(I)*CR4
  103    continue
  104 continue
  return
  END
  subroutine PASSB5 (IDO,L1,CC,CH,WA1,WA2,WA3,WA4)
  DIMENSION       CC(IDO,5,L1)           ,CH(IDO,L1,5), &
                  WA1(1)     ,WA2(1)     ,WA3(1)     ,WA4(1)
  DATA TR11,TI11,TR12,TI12 /.309016994374947,.951056516295154, &
  -.809016994374947,.587785252292473/
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TI5 = CC(2,2,K)-CC(2,5,K)
   TI2 = CC(2,2,K)+CC(2,5,K)
   TI4 = CC(2,3,K)-CC(2,4,K)
   TI3 = CC(2,3,K)+CC(2,4,K)
   TR5 = CC(1,2,K)-CC(1,5,K)
   TR2 = CC(1,2,K)+CC(1,5,K)
   TR4 = CC(1,3,K)-CC(1,4,K)
   TR3 = CC(1,3,K)+CC(1,4,K)
   CH(1,K,1) = CC(1,1,K)+TR2+TR3
   CH(2,K,1) = CC(2,1,K)+TI2+TI3
   CR2 = CC(1,1,K)+TR11*TR2+TR12*TR3
   CI2 = CC(2,1,K)+TR11*TI2+TR12*TI3
   CR3 = CC(1,1,K)+TR12*TR2+TR11*TR3
   CI3 = CC(2,1,K)+TR12*TI2+TR11*TI3
   CR5 = TI11*TR5+TI12*TR4
   CI5 = TI11*TI5+TI12*TI4
   CR4 = TI12*TR5-TI11*TR4
   CI4 = TI12*TI5-TI11*TI4
   CH(1,K,2) = CR2-CI5
   CH(1,K,5) = CR2+CI5
   CH(2,K,2) = CI2+CR5
   CH(2,K,3) = CI3+CR4
   CH(1,K,3) = CR3-CI4
   CH(1,K,4) = CR3+CI4
   CH(2,K,4) = CI3-CR4
   CH(2,K,5) = CI2-CR5
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TI5 = CC(I,2,K)-CC(I,5,K)
      TI2 = CC(I,2,K)+CC(I,5,K)
      TI4 = CC(I,3,K)-CC(I,4,K)
      TI3 = CC(I,3,K)+CC(I,4,K)
      TR5 = CC(I-1,2,K)-CC(I-1,5,K)
      TR2 = CC(I-1,2,K)+CC(I-1,5,K)
      TR4 = CC(I-1,3,K)-CC(I-1,4,K)
      TR3 = CC(I-1,3,K)+CC(I-1,4,K)
      CH(I-1,K,1) = CC(I-1,1,K)+TR2+TR3
      CH(I,K,1) = CC(I,1,K)+TI2+TI3
      CR2 = CC(I-1,1,K)+TR11*TR2+TR12*TR3
      CI2 = CC(I,1,K)+TR11*TI2+TR12*TI3
      CR3 = CC(I-1,1,K)+TR12*TR2+TR11*TR3
      CI3 = CC(I,1,K)+TR12*TI2+TR11*TI3
      CR5 = TI11*TR5+TI12*TR4
      CI5 = TI11*TI5+TI12*TI4
      CR4 = TI12*TR5-TI11*TR4
      CI4 = TI12*TI5-TI11*TI4
      DR3 = CR3-CI4
      DR4 = CR3+CI4
      DI3 = CI3+CR4
      DI4 = CI3-CR4
      DR5 = CR2+CI5
      DR2 = CR2-CI5
      DI5 = CI2-CR5
      DI2 = CI2+CR5
      CH(I-1,K,2) = WA1(I-1)*DR2-WA1(I)*DI2
      CH(I,K,2) = WA1(I-1)*DI2+WA1(I)*DR2
      CH(I-1,K,3) = WA2(I-1)*DR3-WA2(I)*DI3
      CH(I,K,3) = WA2(I-1)*DI3+WA2(I)*DR3
      CH(I-1,K,4) = WA3(I-1)*DR4-WA3(I)*DI4
      CH(I,K,4) = WA3(I-1)*DI4+WA3(I)*DR4
      CH(I-1,K,5) = WA4(I-1)*DR5-WA4(I)*DI5
      CH(I,K,5) = WA4(I-1)*DI5+WA4(I)*DR5
  103    continue
  104 continue
  return
  END



  subroutine CFFTI (N,WSAVE)
  DIMENSION       WSAVE(1)
  if (N == 1) return
  IW1 = N+N+1
  IW2 = IW1+N+N
  CALL CFFTI1 (N,WSAVE(IW1),WSAVE(IW2))
  return
  END
  subroutine CFFTI1 (N,WA,IFAC)
  DIMENSION       WA(1)      ,IFAC(1)    ,NTRYH(4)
  DATA NTRYH(1),NTRYH(2),NTRYH(3),NTRYH(4)/3,4,2,5/
  NL = N
  NF = 0
  J = 0
  101 J = J+1
  if (J-4) 102,102,103
  102 NTRY = NTRYH(J)
  goto 104
  103 NTRY = NTRY+2
  104 NQ = NL/NTRY
  NR = NL-NTRY*NQ
  if (NR) 101,105,101
  105 NF = NF+1
  IFAC(NF+2) = NTRY
  NL = NQ
  if (NTRY /= 2) goto 107
  if (NF == 1) goto 107
  DO 106 I=2,NF
   IB = NF-I+2
   IFAC(IB+2) = IFAC(IB+1)
  106 continue
  IFAC(3) = 2
  107 if (NL /= 1) goto 104
  IFAC(1) = N
  IFAC(2) = NF
  TPI = 6.28318530717959
  ARGH = TPI/FLOAT(N)
  I = 2
  L1 = 1
  DO 110 K1=1,NF
   IP = IFAC(K1+2)
   LD = 0
   L2 = L1*IP
   IDO = N/L2
   IDOT = IDO+IDO+2
   IPM = IP-1
   DO 109 J=1,IPM
      I1 = I
      WA(I-1) = 1.
      WA(I) = 0.
      LD = LD+L1
      FI = 0.
      ARGLD = FLOAT(LD)*ARGH
      DO 108 II=4,IDOT,2
         I = I+2
         FI = FI+1.
         ARG = FI*ARGLD
         WA(I-1) = COS(ARG)
         WA(I) = SIN(ARG)
  108       continue
      if (IP <= 5) goto 109
      WA(I1-1) = WA(I-1)
      WA(I1) = WA(I)
  109    continue
   L1 = L2
  110 continue
  return
  END





  subroutine CFFTF (N,C,WSAVE)
  DIMENSION       C(1)       ,WSAVE(1)
  if (N == 1) return
  IW1 = N+N+1
  IW2 = IW1+N+N
  CALL CFFTF1 (N,C,WSAVE,WSAVE(IW1),WSAVE(IW2))
  return
  END
  subroutine CFFTF1 (N,C,CH,WA,IFAC)
  DIMENSION       CH(1)      ,C(1)       ,WA(1)      ,IFAC(1)
  NF = IFAC(2)
  NA = 0
  L1 = 1
  IW = 1
  DO 116 K1=1,NF
   IP = IFAC(K1+2)
   L2 = IP*L1
   IDO = N/L2
   IDOT = IDO+IDO
   IDL1 = IDOT*L1
   if (IP /= 4) goto 103
   IX2 = IW+IDOT
   IX3 = IX2+IDOT
   if (NA /= 0) goto 101
   CALL PASSF4 (IDOT,L1,C,CH,WA(IW),WA(IX2),WA(IX3))
   goto 102
  101    CALL PASSF4 (IDOT,L1,CH,C,WA(IW),WA(IX2),WA(IX3))
  102    NA = 1-NA
   goto 115
  103    if (IP /= 2) goto 106
   if (NA /= 0) goto 104
   CALL PASSF2 (IDOT,L1,C,CH,WA(IW))
   goto 105
  104    CALL PASSF2 (IDOT,L1,CH,C,WA(IW))
  105    NA = 1-NA
   goto 115
  106    if (IP /= 3) goto 109
   IX2 = IW+IDOT
   if (NA /= 0) goto 107
   CALL PASSF3 (IDOT,L1,C,CH,WA(IW),WA(IX2))
   goto 108
  107    CALL PASSF3 (IDOT,L1,CH,C,WA(IW),WA(IX2))
  108    NA = 1-NA
   goto 115
  109    if (IP /= 5) goto 112
   IX2 = IW+IDOT
   IX3 = IX2+IDOT
   IX4 = IX3+IDOT
   if (NA /= 0) goto 110
   CALL PASSF5 (IDOT,L1,C,CH,WA(IW),WA(IX2),WA(IX3),WA(IX4))
   goto 111
  110    CALL PASSF5 (IDOT,L1,CH,C,WA(IW),WA(IX2),WA(IX3),WA(IX4))
  111    NA = 1-NA
   goto 115
  112    if (NA /= 0) goto 113
   CALL PASSF (NAC,IDOT,IP,L1,IDL1,C,C,C,CH,CH,WA(IW))
   goto 114
  113    CALL PASSF (NAC,IDOT,IP,L1,IDL1,CH,CH,CH,C,C,WA(IW))
  114    if (NAC /= 0) NA = 1-NA
  115    L1 = L2
   IW = IW+(IP-1)*IDOT
  116 continue
  if (NA == 0) return
  N2 = N+N
  DO 117 I=1,N2
   C(I) = CH(I)
  117 continue
  return
  END
  subroutine PASSF (NAC,IDO,IP,L1,IDL1,CC,C1,C2,CH,CH2,WA)
  DIMENSION       CH(IDO,L1,IP)          ,CC(IDO,IP,L1), &
                  C1(IDO,L1,IP)          ,WA(1)      ,C2(IDL1,IP), &
                  CH2(IDL1,IP)
  IDOT = IDO/2
  NT = IP*IDL1
  IPP2 = IP+2
  IPPH = (IP+1)/2
  IDP = IP*IDO
!
  if (IDO < L1) goto 106
  DO 103 J=2,IPPH
   JC = IPP2-J
   DO 102 K=1,L1
      DO 101 I=1,IDO
         CH(I,K,J) = CC(I,J,K)+CC(I,JC,K)
         CH(I,K,JC) = CC(I,J,K)-CC(I,JC,K)
  101       continue
  102    continue
  103 continue
  DO 105 K=1,L1
   DO 104 I=1,IDO
      CH(I,K,1) = CC(I,1,K)
  104    continue
  105 continue
  goto 112
  106 DO 109 J=2,IPPH
   JC = IPP2-J
   DO 108 I=1,IDO
      DO 107 K=1,L1
         CH(I,K,J) = CC(I,J,K)+CC(I,JC,K)
         CH(I,K,JC) = CC(I,J,K)-CC(I,JC,K)
  107       continue
  108    continue
  109 continue
  DO 111 I=1,IDO
   DO 110 K=1,L1
      CH(I,K,1) = CC(I,1,K)
  110    continue
  111 continue
  112 IDL = 2-IDO
  INC = 0
  DO 116 L=2,IPPH
   LC = IPP2-L
   IDL = IDL+IDO
   DO 113 IK=1,IDL1
      C2(IK,L) = CH2(IK,1)+WA(IDL-1)*CH2(IK,2)
      C2(IK,LC) = -WA(IDL)*CH2(IK,IP)
  113    continue
   IDLJ = IDL
   INC = INC+IDO
   DO 115 J=3,IPPH
      JC = IPP2-J
      IDLJ = IDLJ+INC
      if (IDLJ > IDP) IDLJ = IDLJ-IDP
      WAR = WA(IDLJ-1)
      WAI = WA(IDLJ)
      DO 114 IK=1,IDL1
         C2(IK,L) = C2(IK,L)+WAR*CH2(IK,J)
         C2(IK,LC) = C2(IK,LC)-WAI*CH2(IK,JC)
  114       continue
  115    continue
  116 continue
  DO 118 J=2,IPPH
   DO 117 IK=1,IDL1
      CH2(IK,1) = CH2(IK,1)+CH2(IK,J)
  117    continue
  118 continue
  DO 120 J=2,IPPH
   JC = IPP2-J
   DO 119 IK=2,IDL1,2
      CH2(IK-1,J) = C2(IK-1,J)-C2(IK,JC)
      CH2(IK-1,JC) = C2(IK-1,J)+C2(IK,JC)
      CH2(IK,J) = C2(IK,J)+C2(IK-1,JC)
      CH2(IK,JC) = C2(IK,J)-C2(IK-1,JC)
  119    continue
  120 continue
  NAC = 1
  if (IDO == 2) return
  NAC = 0
  DO 121 IK=1,IDL1
   C2(IK,1) = CH2(IK,1)
  121 continue
  DO 123 J=2,IP
   DO 122 K=1,L1
      C1(1,K,J) = CH(1,K,J)
      C1(2,K,J) = CH(2,K,J)
  122    continue
  123 continue
  if (IDOT > L1) goto 127
  IDIJ = 0
  DO 126 J=2,IP
   IDIJ = IDIJ+2
   DO 125 I=4,IDO,2
      IDIJ = IDIJ+2
      DO 124 K=1,L1
         C1(I-1,K,J) = WA(IDIJ-1)*CH(I-1,K,J)+WA(IDIJ)*CH(I,K,J)
         C1(I,K,J) = WA(IDIJ-1)*CH(I,K,J)-WA(IDIJ)*CH(I-1,K,J)
  124       continue
  125    continue
  126 continue
  return
  127 IDJ = 2-IDO
  DO 130 J=2,IP
   IDJ = IDJ+IDO
   DO 129 K=1,L1
      IDIJ = IDJ
      DO 128 I=4,IDO,2
         IDIJ = IDIJ+2
         C1(I-1,K,J) = WA(IDIJ-1)*CH(I-1,K,J)+WA(IDIJ)*CH(I,K,J)
         C1(I,K,J) = WA(IDIJ-1)*CH(I,K,J)-WA(IDIJ)*CH(I-1,K,J)
  128       continue
  129    continue
  130 continue
  return
  END
  subroutine PASSF2 (IDO,L1,CC,CH,WA1)
  DIMENSION       CC(IDO,2,L1)           ,CH(IDO,L1,2), &
                  WA1(1)
  if (IDO > 2) goto 102
  DO 101 K=1,L1
   CH(1,K,1) = CC(1,1,K)+CC(1,2,K)
   CH(1,K,2) = CC(1,1,K)-CC(1,2,K)
   CH(2,K,1) = CC(2,1,K)+CC(2,2,K)
   CH(2,K,2) = CC(2,1,K)-CC(2,2,K)
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      CH(I-1,K,1) = CC(I-1,1,K)+CC(I-1,2,K)
      TR2 = CC(I-1,1,K)-CC(I-1,2,K)
      CH(I,K,1) = CC(I,1,K)+CC(I,2,K)
      TI2 = CC(I,1,K)-CC(I,2,K)
      CH(I,K,2) = WA1(I-1)*TI2-WA1(I)*TR2
      CH(I-1,K,2) = WA1(I-1)*TR2+WA1(I)*TI2
  103    continue
  104 continue
  return
  END
  subroutine PASSF3 (IDO,L1,CC,CH,WA1,WA2)
  DIMENSION       CC(IDO,3,L1)           ,CH(IDO,L1,3), &
                  WA1(1)     ,WA2(1)
  DATA TAUR,TAUI /-.5,-.866025403784439/
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TR2 = CC(1,2,K)+CC(1,3,K)
   CR2 = CC(1,1,K)+TAUR*TR2
   CH(1,K,1) = CC(1,1,K)+TR2
   TI2 = CC(2,2,K)+CC(2,3,K)
   CI2 = CC(2,1,K)+TAUR*TI2
   CH(2,K,1) = CC(2,1,K)+TI2
   CR3 = TAUI*(CC(1,2,K)-CC(1,3,K))
   CI3 = TAUI*(CC(2,2,K)-CC(2,3,K))
   CH(1,K,2) = CR2-CI3
   CH(1,K,3) = CR2+CI3
   CH(2,K,2) = CI2+CR3
   CH(2,K,3) = CI2-CR3
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TR2 = CC(I-1,2,K)+CC(I-1,3,K)
      CR2 = CC(I-1,1,K)+TAUR*TR2
      CH(I-1,K,1) = CC(I-1,1,K)+TR2
      TI2 = CC(I,2,K)+CC(I,3,K)
      CI2 = CC(I,1,K)+TAUR*TI2
      CH(I,K,1) = CC(I,1,K)+TI2
      CR3 = TAUI*(CC(I-1,2,K)-CC(I-1,3,K))
      CI3 = TAUI*(CC(I,2,K)-CC(I,3,K))
      DR2 = CR2-CI3
      DR3 = CR2+CI3
      DI2 = CI2+CR3
      DI3 = CI2-CR3
      CH(I,K,2) = WA1(I-1)*DI2-WA1(I)*DR2
      CH(I-1,K,2) = WA1(I-1)*DR2+WA1(I)*DI2
      CH(I,K,3) = WA2(I-1)*DI3-WA2(I)*DR3
      CH(I-1,K,3) = WA2(I-1)*DR3+WA2(I)*DI3
  103    continue
  104 continue
  return
  END
  subroutine PASSF4 (IDO,L1,CC,CH,WA1,WA2,WA3)
  DIMENSION       CC(IDO,4,L1)           ,CH(IDO,L1,4), &
                  WA1(1)     ,WA2(1)     ,WA3(1)
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TI1 = CC(2,1,K)-CC(2,3,K)
   TI2 = CC(2,1,K)+CC(2,3,K)
   TR4 = CC(2,2,K)-CC(2,4,K)
   TI3 = CC(2,2,K)+CC(2,4,K)
   TR1 = CC(1,1,K)-CC(1,3,K)
   TR2 = CC(1,1,K)+CC(1,3,K)
   TI4 = CC(1,4,K)-CC(1,2,K)
   TR3 = CC(1,2,K)+CC(1,4,K)
   CH(1,K,1) = TR2+TR3
   CH(1,K,3) = TR2-TR3
   CH(2,K,1) = TI2+TI3
   CH(2,K,3) = TI2-TI3
   CH(1,K,2) = TR1+TR4
   CH(1,K,4) = TR1-TR4
   CH(2,K,2) = TI1+TI4
   CH(2,K,4) = TI1-TI4
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TI1 = CC(I,1,K)-CC(I,3,K)
      TI2 = CC(I,1,K)+CC(I,3,K)
      TI3 = CC(I,2,K)+CC(I,4,K)
      TR4 = CC(I,2,K)-CC(I,4,K)
      TR1 = CC(I-1,1,K)-CC(I-1,3,K)
      TR2 = CC(I-1,1,K)+CC(I-1,3,K)
      TI4 = CC(I-1,4,K)-CC(I-1,2,K)
      TR3 = CC(I-1,2,K)+CC(I-1,4,K)
      CH(I-1,K,1) = TR2+TR3
      CR3 = TR2-TR3
      CH(I,K,1) = TI2+TI3
      CI3 = TI2-TI3
      CR2 = TR1+TR4
      CR4 = TR1-TR4
      CI2 = TI1+TI4
      CI4 = TI1-TI4
      CH(I-1,K,2) = WA1(I-1)*CR2+WA1(I)*CI2
      CH(I,K,2) = WA1(I-1)*CI2-WA1(I)*CR2
      CH(I-1,K,3) = WA2(I-1)*CR3+WA2(I)*CI3
      CH(I,K,3) = WA2(I-1)*CI3-WA2(I)*CR3
      CH(I-1,K,4) = WA3(I-1)*CR4+WA3(I)*CI4
      CH(I,K,4) = WA3(I-1)*CI4-WA3(I)*CR4
  103    continue
  104 continue
  return
  END
  subroutine PASSF5 (IDO,L1,CC,CH,WA1,WA2,WA3,WA4)
  DIMENSION       CC(IDO,5,L1)           ,CH(IDO,L1,5), &
                  WA1(1)     ,WA2(1)     ,WA3(1)     ,WA4(1)
  DATA TR11,TI11,TR12,TI12 /.309016994374947,-.951056516295154, &
  -.809016994374947,-.587785252292473/
  if (IDO /= 2) goto 102
  DO 101 K=1,L1
   TI5 = CC(2,2,K)-CC(2,5,K)
   TI2 = CC(2,2,K)+CC(2,5,K)
   TI4 = CC(2,3,K)-CC(2,4,K)
   TI3 = CC(2,3,K)+CC(2,4,K)
   TR5 = CC(1,2,K)-CC(1,5,K)
   TR2 = CC(1,2,K)+CC(1,5,K)
   TR4 = CC(1,3,K)-CC(1,4,K)
   TR3 = CC(1,3,K)+CC(1,4,K)
   CH(1,K,1) = CC(1,1,K)+TR2+TR3
   CH(2,K,1) = CC(2,1,K)+TI2+TI3
   CR2 = CC(1,1,K)+TR11*TR2+TR12*TR3
   CI2 = CC(2,1,K)+TR11*TI2+TR12*TI3
   CR3 = CC(1,1,K)+TR12*TR2+TR11*TR3
   CI3 = CC(2,1,K)+TR12*TI2+TR11*TI3
   CR5 = TI11*TR5+TI12*TR4
   CI5 = TI11*TI5+TI12*TI4
   CR4 = TI12*TR5-TI11*TR4
   CI4 = TI12*TI5-TI11*TI4
   CH(1,K,2) = CR2-CI5
   CH(1,K,5) = CR2+CI5
   CH(2,K,2) = CI2+CR5
   CH(2,K,3) = CI3+CR4
   CH(1,K,3) = CR3-CI4
   CH(1,K,4) = CR3+CI4
   CH(2,K,4) = CI3-CR4
   CH(2,K,5) = CI2-CR5
  101 continue
  return
  102 DO 104 K=1,L1
   DO 103 I=2,IDO,2
      TI5 = CC(I,2,K)-CC(I,5,K)
      TI2 = CC(I,2,K)+CC(I,5,K)
      TI4 = CC(I,3,K)-CC(I,4,K)
      TI3 = CC(I,3,K)+CC(I,4,K)
      TR5 = CC(I-1,2,K)-CC(I-1,5,K)
      TR2 = CC(I-1,2,K)+CC(I-1,5,K)
      TR4 = CC(I-1,3,K)-CC(I-1,4,K)
      TR3 = CC(I-1,3,K)+CC(I-1,4,K)
      CH(I-1,K,1) = CC(I-1,1,K)+TR2+TR3
      CH(I,K,1) = CC(I,1,K)+TI2+TI3
      CR2 = CC(I-1,1,K)+TR11*TR2+TR12*TR3
      CI2 = CC(I,1,K)+TR11*TI2+TR12*TI3
      CR3 = CC(I-1,1,K)+TR12*TR2+TR11*TR3
      CI3 = CC(I,1,K)+TR12*TI2+TR11*TI3
      CR5 = TI11*TR5+TI12*TR4
      CI5 = TI11*TI5+TI12*TI4
      CR4 = TI12*TR5-TI11*TR4
      CI4 = TI12*TI5-TI11*TI4
      DR3 = CR3-CI4
      DR4 = CR3+CI4
      DI3 = CI3+CR4
      DI4 = CI3-CR4
      DR5 = CR2+CI5
      DR2 = CR2-CI5
      DI5 = CI2-CR5
      DI2 = CI2+CR5
      CH(I-1,K,2) = WA1(I-1)*DR2+WA1(I)*DI2
      CH(I,K,2) = WA1(I-1)*DI2-WA1(I)*DR2
      CH(I-1,K,3) = WA2(I-1)*DR3+WA2(I)*DI3
      CH(I,K,3) = WA2(I-1)*DI3-WA2(I)*DR3
      CH(I-1,K,4) = WA3(I-1)*DR4+WA3(I)*DI4
      CH(I,K,4) = WA3(I-1)*DI4-WA3(I)*DR4
      CH(I-1,K,5) = WA4(I-1)*DR5+WA4(I)*DI5
      CH(I,K,5) = WA4(I-1)*DI5-WA4(I)*DR5
  103    continue
  104 continue
  return
  END

