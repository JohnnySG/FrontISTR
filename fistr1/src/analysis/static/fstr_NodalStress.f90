!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 3.2                                   !
!                                                                      !
!      Module Name : Static Analysis                                   !
!                                                                      !
!            Written by K. Suemitsu(AdavanceSoft)                      !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!
!======================================================================!
!
!> \brief  This module provides functions to caluclation nodal stress
!!
!>  \author     K. Suemitsu(AdavanceSoft)
!>  \date       2012/01/16
!>  \version    0.00
!!
!======================================================================!
module m_fstr_NodalStress
  implicit none

  private :: NodalStress_INV3, NodalStress_INV2, inverse_func

  contains

!> Calculate NODAL STRESS of solid elements
!----------------------------------------------------------------------*
  subroutine fstr_NodalStress3D( hecMESH, fstrSOLID, tnstrain, testrain )
!----------------------------------------------------------------------*
    use m_fstr
    use m_static_lib
    type (hecmwST_local_mesh) :: hecMESH
    type (fstr_solid)         :: fstrSOLID
    real(kind=kreal), pointer :: tnstrain(:), testrain(:)
!C** local variables
    integer(kind=kint) :: itype, icel, ic, iS, iE, jS, i, j, ic_type, nn, ni, ID_area, truss
    real(kind=kreal)   :: estrain(6), estress(6), tstrain(6), naturalCoord(3)
    real(kind=kreal)   :: edstrain(20,6), edstress(20,6), tdstrain(20,6)
    real(kind=kreal)   :: s11, s22, s33, s12, s23, s13, ps, smises
    real(kind=kreal), allocatable :: func(:,:), inv_func(:,:)
    real(kind=kreal), allocatable :: trstrain(:,:), trstress(:,:)
    integer(kind=kint), allocatable :: nnumber(:), tnumber(:)

    fstrSOLID%STRAIN = 0.0d0
    fstrSOLID%STRESS = 0.0d0
    allocate( nnumber(hecMESH%n_node) )
    nnumber = 0
    if( associated(tnstrain) ) tnstrain = 0.0d0

    truss = 0
    do itype = 1, hecMESH%n_elem_type
      ic_type = hecMESH%elem_type_item(itype)
      if( ic_type == 301 ) truss = 1
    enddo
    if( truss == 1 ) then
      allocate( trstrain(hecMESH%n_node,6), trstress(hecMESH%n_node,6) )
      allocate( tnumber(hecMESH%n_node) )
      trstrain = 0.0d0
      trstress = 0.0d0
      tnumber = 0
    endif

!C +-------------------------------+
!C | according to ELEMENT TYPE     |
!C +-------------------------------+
    do itype = 1, hecMESH%n_elem_type
      iS = hecMESH%elem_type_index(itype-1) + 1
      iE = hecMESH%elem_type_index(itype  )
      ic_type = hecMESH%elem_type_item(itype)
      if( ic_type == fe_tet10nc ) ic_type = fe_tet10n
      if( .not. hecmw_is_etype_solid(ic_type) ) cycle
!C** set number of nodes and shape function
      nn = hecmw_get_max_node( ic_type )
      ni = NumOfQuadPoints( ic_type )
      allocate( func(ni,nn), inv_func(nn,ni) )
      if( ic_type == fe_tet10n ) then
        ic = hecmw_get_max_node( fe_tet4n )
        do i = 1, ni
          call getQuadPoint( ic_type, i, naturalCoord )
          call getShapeFunc( fe_tet4n, naturalCoord, func(i,1:ic) )
        enddo
        call inverse_func( ic, func, inv_func )
      else if( ic_type == fe_hex8n ) then
        do i = 1, ni
          call getQuadPoint( ic_type, i, naturalCoord )
          call getShapeFunc( ic_type, naturalCoord, func(i,1:nn) )
        enddo
        call inverse_func( ni, func, inv_func )
      else if( ic_type == fe_prism15n ) then
        ic = 0
        do i = 1, ni
          if( i==1 .or. i==2 .or. i==3 .or. i==7 .or. i==8 .or. i==9 ) then
            ic = ic + 1
            call getQuadPoint( ic_type, i, naturalCoord )
            call getShapeFunc( fe_prism6n, naturalCoord, func(ic,1:6) )
          endif
        enddo
        call inverse_func( ic, func, inv_func )
        ni = ic
      else if( ic_type == fe_hex20n ) then
        ic = 0
        do i = 1, ni
          if( i==1 .or. i==3 .or. i==7 .or. i==9 .or. &
              i==19 .or. i==21 .or. i==25 .or. i==27 ) then
            ic = ic + 1
            call getQuadPoint( ic_type, i, naturalCoord )
            call getShapeFunc( fe_hex8n, naturalCoord, func(ic,1:8) )
           endif
        enddo
        call inverse_func( ic, func, inv_func )
        ni = ic
      endif
!C** element loop
      do icel = iS, iE
        jS = hecMESH%elem_node_index(icel-1)
        ID_area = hecMESH%elem_ID(icel*2)
!--- calculate nodal stress and strain
        if( ic_type == 301 ) then
          call NodalStress_C1( ic_type, nn, fstrSOLID%elements(icel)%gausses, &
                               edstrain(1:nn,1:6), edstress(1:nn,1:6) )
        else if( ic_type == fe_tet10n .or. ic_type == fe_hex8n .or. &
                 ic_type == fe_prism15n .or. ic_type == fe_hex20n ) then
          call NodalStress_INV3( ic_type, ni, fstrSOLID%elements(icel)%gausses, &
                                 inv_func, edstrain(1:nn,1:6), edstress(1:nn,1:6), &
                                 tdstrain(1:nn,1:6) )
        else
          call NodalStress_C3( ic_type, nn, fstrSOLID%elements(icel)%gausses, &
                               edstrain(1:nn,1:6), edstress(1:nn,1:6) )
!          call NodalStress_C3( ic_type, nn, fstrSOLID%elements(icel)%gausses, &
!                               edstrain(1:nn,1:6), edstress(1:nn,1:6), tdstrain(1:nn,1:6) )
        endif
        do j = 1, nn
          ic = hecMESH%elem_node_item(jS+j)
          if( ic_type == 301 ) then
            trstrain(ic,1:6) = trstrain(ic,1:6) + edstrain(j,1:6)
            trstress(ic,1:6) = trstress(ic,1:6) + edstress(j,1:6)
            tnumber(ic) = tnumber(ic) + 1
          else
            fstrSOLID%STRAIN(6*ic-5:6*ic) = fstrSOLID%STRAIN(6*ic-5:6*ic) + edstrain(j,1:6)
            fstrSOLID%STRESS(7*ic-6:7*ic-1) = fstrSOLID%STRESS(7*ic-6:7*ic-1) + edstress(j,1:6)
            if( associated(tnstrain) ) tnstrain(6*ic-5:6*ic) = tnstrain(6*ic-5:6*ic) + tdstrain(j,1:6)
            nnumber(ic) = nnumber(ic) + 1
          endif
        enddo
!--- calculate elemental stress and strain
        if( ID_area == hecMESH%my_rank ) then
          if( ic_type == 301 ) then
            call ElementStress_C1( ic_type, fstrSOLID%elements(icel)%gausses, estrain, estress )
          else
            call ElementStress_C3( ic_type, fstrSOLID%elements(icel)%gausses, estrain, estress )
!            call ElementStress_C3( ic_type, fstrSOLID%elements(icel)%gausses, estrain, estress, tstrain )
          endif
          fstrSOLID%ESTRAIN(6*icel-5:6*icel) = estrain
          fstrSOLID%ESTRESS(7*icel-6:7*icel-1) = estress
          if( associated(testrain) ) testrain(6*icel-5:6*icel) = tstrain
          s11 = fstrSOLID%ESTRESS(7*icel-6)
          s22 = fstrSOLID%ESTRESS(7*icel-5)
          s33 = fstrSOLID%ESTRESS(7*icel-4)
          s12 = fstrSOLID%ESTRESS(7*icel-3)
          s23 = fstrSOLID%ESTRESS(7*icel-2)
          s13 = fstrSOLID%ESTRESS(7*icel-1)
          ps = ( s11 + s22 + s33 ) / 3.0
          smises = 0.5d0 * ( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2 + s13**2
          fstrSOLID%ESTRESS(7*icel) = sqrt( 3.0d0 * smises )
        endif
      enddo
      deallocate( func, inv_func )
    enddo

!C** average over nodes
    do i = 1, hecMESH%nn_internal
      if( nnumber(i) == 0 ) cycle
      if( truss == 1 .and. tnumber(i) /= 0 ) then
        fstrSOLID%STRAIN(6*i-5:6*i) = fstrSOLID%STRAIN(6*i-5:6*i) / nnumber(i) + trstrain(i,1:6) / tnumber(i)
        fstrSOLID%STRESS(7*i-6:7*i-1) = fstrSOLID%STRESS(7*i-6:7*i-1) / nnumber(i) + trstress(i,1:6) / tnumber(i)
      else
        fstrSOLID%STRAIN(6*i-5:6*i) = fstrSOLID%STRAIN(6*i-5:6*i) / nnumber(i)
        fstrSOLID%STRESS(7*i-6:7*i-1) = fstrSOLID%STRESS(7*i-6:7*i-1) / nnumber(i)
        if( associated(tnstrain) ) tnstrain(6*i-5:6*i) = tnstrain(6*i-5:6*i) / nnumber(i)
      endif
    enddo
!C** calculate von MISES stress
    do i = 1, hecMESH%n_node
      s11 = fstrSOLID%STRESS(7*i-6)
      s22 = fstrSOLID%STRESS(7*i-5)
      s33 = fstrSOLID%STRESS(7*i-4)
      s12 = fstrSOLID%STRESS(7*i-3)
      s23 = fstrSOLID%STRESS(7*i-2)
      s13 = fstrSOLID%STRESS(7*i-1)
      ps = ( s11 + s22 + s33 ) / 3.0
      smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
      fstrSOLID%STRESS(7*i) = sqrt( 3.0d0 * smises )
    enddo

    deallocate( nnumber )
    if( truss == 1 ) then
      deallocate( trstrain, trstress )
      deallocate( tnumber )
    endif
  end subroutine fstr_NodalStress3D

!----------------------------------------------------------------------*
  subroutine NodalStress_INV3( etype, ni, gausses, func, edstrain, edstress, tdstrain )
!----------------------------------------------------------------------*
    use m_fstr
    use mMechGauss
    integer(kind=kint) :: etype, ni
    type(tGaussStatus) :: gausses(:)
    real(kind=kreal)   :: func(:,:), edstrain(:,:), edstress(:,:), tdstrain(:,:)
    integer :: i, j, k, ic

    edstrain = 0.0d0
    edstress = 0.0d0
    tdstrain = 0.0d0

    if( etype == fe_hex8n ) then
      do i = 1, ni
        do j = 1, ni
          do k = 1, 6
            edstrain(i,k) = edstrain(i,k) + func(i,j) * gausses(j)%strain(k)
            edstress(i,k) = edstress(i,k) + func(i,j) * gausses(j)%stress(k)
!            tdstrain(i,k) = tdstrain(i,k) + func(i,j) * gausses(j)%tstrain(k)
          enddo
        enddo
      enddo
    else if( etype == fe_tet10n ) then
      do i = 1, ni
        do j = 1, ni
          do k = 1, 6
            edstrain(i,k) = edstrain(i,k) + func(i,j) * gausses(j)%strain(k)
            edstress(i,k) = edstress(i,k) + func(i,j) * gausses(j)%stress(k)
!            tdstrain(i,k) = tdstrain(i,k) + func(i,j) * gausses(j)%tstrain(k)
          enddo
        enddo
      enddo
      edstrain(5,1:6) = ( edstrain(1,1:6) + edstrain(2,1:6) ) / 2.0
      edstress(5,1:6) = ( edstress(1,1:6) + edstress(2,1:6) ) / 2.0
      tdstrain(5,1:6) = ( tdstrain(1,1:6) + tdstrain(2,1:6) ) / 2.0
      edstrain(6,1:6) = ( edstrain(2,1:6) + edstrain(3,1:6) ) / 2.0
      edstress(6,1:6) = ( edstress(2,1:6) + edstress(3,1:6) ) / 2.0
      tdstrain(6,1:6) = ( tdstrain(2,1:6) + tdstrain(3,1:6) ) / 2.0
      edstrain(7,1:6) = ( edstrain(3,1:6) + edstrain(1,1:6) ) / 2.0
      edstress(7,1:6) = ( edstress(3,1:6) + edstress(1,1:6) ) / 2.0
      tdstrain(7,1:6) = ( tdstrain(3,1:6) + tdstrain(1,1:6) ) / 2.0
      edstrain(8,1:6) = ( edstrain(1,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(8,1:6) = ( edstress(1,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(8,1:6) = ( tdstrain(1,1:6) + tdstrain(4,1:6) ) / 2.0
      edstrain(9,1:6) = ( edstrain(2,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(9,1:6) = ( edstress(2,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(9,1:6) = ( tdstrain(2,1:6) + tdstrain(4,1:6) ) / 2.0
      edstrain(10,1:6) = ( edstrain(3,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(10,1:6) = ( edstress(3,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(10,1:6) = ( tdstrain(3,1:6) + tdstrain(4,1:6) ) / 2.0
    else if( etype == fe_prism15n ) then
      do i = 1, ni
        ic = 0
        do j = 1, NumOfQuadPoints(etype)
          if( j==1 .or. j==2 .or. j==3 .or. j==7 .or. j==8 .or. j==9 ) then
            ic = ic + 1
            do k = 1, 6
              edstrain(i,k) = edstrain(i,k) + func(i,ic) * gausses(j)%strain(k)
              edstress(i,k) = edstress(i,k) + func(i,ic) * gausses(j)%stress(k)
!              tdstrain(i,k) = tdstrain(i,k) + func(i,ic) * gausses(j)%tstrain(k)
            enddo
          endif
        enddo
      enddo
      edstrain(7,1:6) = ( edstrain(1,1:6) + edstrain(2,1:6) ) / 2.0
      edstress(7,1:6) = ( edstress(1,1:6) + edstress(2,1:6) ) / 2.0
      tdstrain(7,1:6) = ( tdstrain(1,1:6) + tdstrain(2,1:6) ) / 2.0
      edstrain(8,1:6) = ( edstrain(2,1:6) + edstrain(3,1:6) ) / 2.0
      edstress(8,1:6) = ( edstress(2,1:6) + edstress(3,1:6) ) / 2.0
      tdstrain(8,1:6) = ( tdstrain(2,1:6) + tdstrain(3,1:6) ) / 2.0
      edstrain(9,1:6) = ( edstrain(3,1:6) + edstrain(1,1:6) ) / 2.0
      edstress(9,1:6) = ( edstress(3,1:6) + edstress(1,1:6) ) / 2.0
      tdstrain(9,1:6) = ( tdstrain(3,1:6) + tdstrain(1,1:6) ) / 2.0
      edstrain(10,1:6) = ( edstrain(4,1:6) + edstrain(5,1:6) ) / 2.0
      edstress(10,1:6) = ( edstress(4,1:6) + edstress(5,1:6) ) / 2.0
      tdstrain(10,1:6) = ( tdstrain(4,1:6) + tdstrain(5,1:6) ) / 2.0
      edstrain(11,1:6) = ( edstrain(5,1:6) + edstrain(6,1:6) ) / 2.0
      edstress(11,1:6) = ( edstress(5,1:6) + edstress(6,1:6) ) / 2.0
      tdstrain(11,1:6) = ( tdstrain(5,1:6) + tdstrain(6,1:6) ) / 2.0
      edstrain(12,1:6) = ( edstrain(6,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(12,1:6) = ( edstress(6,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(12,1:6) = ( tdstrain(6,1:6) + tdstrain(4,1:6) ) / 2.0
      edstrain(13,1:6) = ( edstrain(1,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(13,1:6) = ( edstress(1,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(13,1:6) = ( tdstrain(1,1:6) + tdstrain(4,1:6) ) / 2.0
      edstrain(14,1:6) = ( edstrain(2,1:6) + edstrain(5,1:6) ) / 2.0
      edstress(14,1:6) = ( edstress(2,1:6) + edstress(5,1:6) ) / 2.0
      tdstrain(14,1:6) = ( tdstrain(2,1:6) + tdstrain(5,1:6) ) / 2.0
      edstrain(15,1:6) = ( edstrain(3,1:6) + edstrain(6,1:6) ) / 2.0
      edstress(15,1:6) = ( edstress(3,1:6) + edstress(6,1:6) ) / 2.0
      tdstrain(15,1:6) = ( tdstrain(3,1:6) + tdstrain(6,1:6) ) / 2.0
    else if( etype == fe_hex20n ) then
      do i = 1, ni
        ic = 0
        do j = 1, NumOfQuadPoints(etype)
          if( j==1 .or. j==3 .or. j==7 .or. j==9 .or. &
              j==19 .or. j==21 .or. j==25 .or. j==27 ) then
            ic = ic + 1
            do k = 1, 6
              edstrain(i,k) = edstrain(i,k) + func(i,ic) * gausses(j)%strain(k)
              edstress(i,k) = edstress(i,k) + func(i,ic) * gausses(j)%stress(k)
!              tdstrain(i,k) = tdstrain(i,k) + func(i,ic) * gausses(j)%tstrain(k)
            enddo
          endif
        enddo
      enddo
      edstrain(9,1:6) = ( edstrain(1,1:6) + edstrain(2,1:6) ) / 2.0
      edstress(9,1:6) = ( edstress(1,1:6) + edstress(2,1:6) ) / 2.0
      tdstrain(9,1:6) = ( tdstrain(1,1:6) + tdstrain(2,1:6) ) / 2.0
      edstrain(10,1:6) = ( edstrain(2,1:6) + edstrain(3,1:6) ) / 2.0
      edstress(10,1:6) = ( edstress(2,1:6) + edstress(3,1:6) ) / 2.0
      tdstrain(10,1:6) = ( tdstrain(2,1:6) + tdstrain(3,1:6) ) / 2.0
      edstrain(11,1:6) = ( edstrain(3,1:6) + edstrain(4,1:6) ) / 2.0
      edstress(11,1:6) = ( edstress(3,1:6) + edstress(4,1:6) ) / 2.0
      tdstrain(11,1:6) = ( tdstrain(3,1:6) + tdstrain(4,1:6) ) / 2.0
      edstrain(12,1:6) = ( edstrain(4,1:6) + edstrain(1,1:6) ) / 2.0
      edstress(12,1:6) = ( edstress(4,1:6) + edstress(1,1:6) ) / 2.0
      tdstrain(12,1:6) = ( tdstrain(4,1:6) + tdstrain(1,1:6) ) / 2.0
      edstrain(13,1:6) = ( edstrain(5,1:6) + edstrain(6,1:6) ) / 2.0
      edstress(13,1:6) = ( edstress(5,1:6) + edstress(6,1:6) ) / 2.0
      tdstrain(13,1:6) = ( tdstrain(5,1:6) + tdstrain(6,1:6) ) / 2.0
      edstrain(14,1:6) = ( edstrain(6,1:6) + edstrain(7,1:6) ) / 2.0
      edstress(14,1:6) = ( edstress(6,1:6) + edstress(7,1:6) ) / 2.0
      tdstrain(14,1:6) = ( tdstrain(6,1:6) + tdstrain(7,1:6) ) / 2.0
      edstrain(15,1:6) = ( edstrain(7,1:6) + edstrain(8,1:6) ) / 2.0
      edstress(15,1:6) = ( edstress(7,1:6) + edstress(8,1:6) ) / 2.0
      tdstrain(15,1:6) = ( tdstrain(7,1:6) + tdstrain(8,1:6) ) / 2.0
      edstrain(16,1:6) = ( edstrain(8,1:6) + edstrain(5,1:6) ) / 2.0
      edstress(16,1:6) = ( edstress(8,1:6) + edstress(5,1:6) ) / 2.0
      tdstrain(16,1:6) = ( tdstrain(8,1:6) + tdstrain(5,1:6) ) / 2.0
      edstrain(17,1:6) = ( edstrain(1,1:6) + edstrain(5,1:6) ) / 2.0
      edstress(17,1:6) = ( edstress(1,1:6) + edstress(5,1:6) ) / 2.0
      tdstrain(17,1:6) = ( tdstrain(1,1:6) + tdstrain(5,1:6) ) / 2.0
      edstrain(18,1:6) = ( edstrain(2,1:6) + edstrain(6,1:6) ) / 2.0
      edstress(18,1:6) = ( edstress(2,1:6) + edstress(6,1:6) ) / 2.0
      tdstrain(18,1:6) = ( tdstrain(2,1:6) + tdstrain(6,1:6) ) / 2.0
      edstrain(19,1:6) = ( edstrain(3,1:6) + edstrain(7,1:6) ) / 2.0
      edstress(19,1:6) = ( edstress(3,1:6) + edstress(7,1:6) ) / 2.0
      tdstrain(19,1:6) = ( tdstrain(3,1:6) + tdstrain(7,1:6) ) / 2.0
      edstrain(20,1:6) = ( edstrain(4,1:6) + edstrain(8,1:6) ) / 2.0
      edstress(20,1:6) = ( edstress(4,1:6) + edstress(8,1:6) ) / 2.0
      tdstrain(20,1:6) = ( tdstrain(4,1:6) + tdstrain(8,1:6) ) / 2.0
    endif
  end subroutine NodalStress_INV3

!> Calculate NODAL STRESS of plane elements
!----------------------------------------------------------------------*
  subroutine fstr_NodalStress2D( hecMESH, fstrSOLID, tnstrain, testrain )
!----------------------------------------------------------------------*
    use m_fstr
    use m_static_lib
    type (hecmwST_local_mesh) :: hecMESH
    type (fstr_solid)         :: fstrSOLID
    real(kind=kreal), pointer :: tnstrain(:), testrain(:)
!C** local variables
    integer(kind=kint) :: itype, icel, ic, iS, iE, jS, i, j, ic_type, nn, ni, ID_area
    real(kind=kreal)   :: estrain(4), estress(4), tstrain(4), naturalCoord(4)
    real(kind=kreal)   :: edstrain(8,4), edstress(8,4), tdstrain(8,4)
    real(kind=kreal)   :: s11, s22, s33, s12, s23, s13, ps, smises
    real(kind=kreal), allocatable :: func(:,:), inv_func(:,:)
    integer(kind=kint), allocatable :: nnumber(:)

    allocate( nnumber(hecMESH%n_node) )
    fstrSOLID%STRAIN = 0.0d0
    fstrSOLID%STRESS = 0.0d0
    nnumber = 0

!C +-------------------------------+
!C | according to ELEMENT TYPE     |
!C +-------------------------------+
    do itype = 1, hecMESH%n_elem_type
      iS = hecMESH%elem_type_index(itype-1) + 1
      iE = hecMESH%elem_type_index(itype  )
      ic_type = hecMESH%elem_type_item(itype)
      if( .not. hecmw_is_etype_surface(ic_type) ) cycle
!C** set number of nodes and shape function
      nn = hecmw_get_max_node( ic_type )
      ni = NumOfQuadPoints( ic_type )
      allocate( func(ni,nn), inv_func(nn,ni) )
      if( ic_type == fe_tri6n ) then
        ic = hecmw_get_max_node( fe_tri3n )
        do i = 1, ni
          call getQuadPoint( ic_type, i, naturalCoord )
          call getShapeFunc( fe_tri3n, naturalCoord, func(i,1:ic) )
        enddo
        call inverse_func( ic, func, inv_func )
      else if( ic_type == fe_quad4n ) then
        do i = 1, ni
          call getQuadPoint( ic_type, i, naturalCoord )
          call getShapeFunc( ic_type, naturalCoord, func(i,1:nn) )
        enddo
        call inverse_func( ni, func, inv_func )
      else if( ic_type == fe_quad8n ) then
        ic = 0
        do i = 1, ni
          if( i==1 .or. i==3 .or. i==7 .or. i==9 ) then
            ic = ic + 1
            call getQuadPoint( ic_type, i, naturalCoord )
            call getShapeFunc( fe_quad4n, naturalCoord, func(ic,1:4) )
          endif
        enddo
        call inverse_func( ic, func, inv_func )
        ni = ic
      endif
!C** element loop
      do icel = iS, iE
        jS = hecMESH%elem_node_index(icel-1)
        ID_area = hecMESH%elem_ID(icel*2)
!--- calculate nodal stress and strain
        if( ic_type == fe_tri6n .or. ic_type == fe_quad4n .or. ic_type == fe_quad8n ) then
          call NodalStress_INV2( ic_type, ni, fstrSOLID%elements(icel)%gausses, &
                                 inv_func, edstrain(1:nn,1:4), edstress(1:nn,1:4), &
                                 tdstrain(1:nn,1:4) )
        else
          call NodalStress_C2( ic_type, nn, fstrSOLID%elements(icel)%gausses, &
                               edstrain(1:nn,1:4), edstress(1:nn,1:4) )
!          call NodalStress_C2( ic_type, nn, fstrSOLID%elements(icel)%gausses, &
!                               edstrain(1:nn,1:4), edstress(1:nn,1:4), tdstrain(1:nn,1:4) )
        endif
        do j = 1, nn
          ic = hecMESH%elem_node_item(jS+j)
          fstrSOLID%STRAIN(6*ic-5:6*ic-2) = fstrSOLID%STRAIN(6*ic-5:6*ic-2) + edstrain(j,1:4)
          fstrSOLID%STRESS(7*ic-6:7*ic-3) = fstrSOLID%STRESS(7*ic-6:7*ic-3) + edstress(j,1:4)
          if( associated(tnstrain) ) then
            tnstrain(3*ic-2) = tnstrain(3*ic-2) + tdstrain(j,1)
            tnstrain(3*ic-1) = tnstrain(3*ic-1) + tdstrain(j,2)
            tnstrain(3*ic  ) = tnstrain(3*ic  ) + tdstrain(j,4)
          endif
          nnumber(ic) = nnumber(ic) + 1
        enddo
!--- calculate elemental stress and strain
        if( ID_area == hecMESH%my_rank ) then
          call ElementStress_C2( ic_type, fstrSOLID%elements(icel)%gausses, estrain, estress )
!          call ElementStress_C2( ic_type, fstrSOLID%elements(icel)%gausses, estrain, estress, tstrain )
          fstrSOLID%ESTRAIN(6*icel-5:6*icel-2) = estrain
          fstrSOLID%ESTRESS(7*icel-6:7*icel-3) = estress
          if( associated(testrain) ) then
            testrain(3*icel-2) = tstrain(1)
            testrain(3*icel-1) = tstrain(2)
            testrain(3*icel  ) = tstrain(4)
          endif
          s11 = fstrSOLID%ESTRESS(7*icel-6)
          s22 = fstrSOLID%ESTRESS(7*icel-5)
          s33 = fstrSOLID%ESTRESS(7*icel-4)
          s12 = fstrSOLID%ESTRESS(7*icel-3)
          s23 = 0.0d0
          s13 = 0.0d0
          ps = ( s11 + s22 + s33 ) / 3.0
          smises = 0.5d0 * ( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2 + s13**2
          fstrSOLID%ESTRESS(7*icel) = sqrt( 3.0d0 * smises )
        endif
      enddo
      deallocate( func, inv_func )
    enddo

!C** average over nodes
    do i = 1, hecMESH%nn_internal
      if( nnumber(i) == 0 ) cycle
      fstrSOLID%STRAIN(6*i-5:6*i-2) = fstrSOLID%STRAIN(6*i-5:6*i-2) / nnumber(i)
      fstrSOLID%STRESS(7*i-6:7*i-3) = fstrSOLID%STRESS(7*i-6:7*i-3) / nnumber(i)
      if( associated(tnstrain) ) tnstrain(3*i-2:3*i) = tnstrain(3*i-2:3*i) / nnumber(i)
    enddo
!C** calculate von MISES stress
    do i = 1, hecMESH%n_node
      s11 = fstrSOLID%STRESS(7*i-6)
      s22 = fstrSOLID%STRESS(7*i-5)
      s33 = fstrSOLID%STRESS(7*i-4)
      s12 = fstrSOLID%STRESS(7*i-3)
      s23 = 0.0d0
      s13 = 0.0d0
      ps = ( s11 + s22 + s33 ) / 3.0
      smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
      fstrSOLID%ESTRESS(7*i) = sqrt( 3.0d0 * smises )
    enddo
!C** set array 
    do i = 1, hecMESH%n_node
      fstrSOLID%STRAIN(6*(i-1)+3) = fstrSOLID%STRAIN(6*(i-1)+4)
      fstrSOLID%STRAIN(6*(i-1)+4) = 0.0d0
      fstrSOLID%STRESS(7*(i-1)+3) = fstrSOLID%STRESS(7*(i-1)+4)
      fstrSOLID%STRESS(7*(i-1)+4) = fstrSOLID%STRESS(7*i)
      fstrSOLID%STRESS(7*i) = 0.0d0
      fstrSOLID%ESTRAIN(6*(i-1)+3) = fstrSOLID%ESTRAIN(6*(i-1)+4)
      fstrSOLID%ESTRAIN(6*(i-1)+4) = 0.0d0
      fstrSOLID%ESTRESS(7*(i-1)+3) = fstrSOLID%ESTRESS(7*(i-1)+4)
      fstrSOLID%ESTRESS(7*(i-1)+4) = fstrSOLID%ESTRESS(7*i)
      fstrSOLID%ESTRESS(7*i) = 0.0d0
    enddo

    deallocate( nnumber )
  end subroutine fstr_NodalStress2D

!----------------------------------------------------------------------*
  subroutine NodalStress_INV2( etype, ni, gausses, func, edstrain, edstress, tdstrain )
!----------------------------------------------------------------------*
    use m_fstr
    use mMechGauss
    integer(kind=kint) :: etype, ni
    type(tGaussStatus) :: gausses(:)
    real(kind=kreal)   :: func(:,:), edstrain(:,:), edstress(:,:), tdstrain(:,:)
    integer :: i, j, k, ic

    edstrain = 0.0d0
    edstress = 0.0d0
    tdstrain = 0.0d0

    if( etype == fe_quad4n ) then
      do i = 1, ni
        do j = 1, ni
          do k = 1, 4
            edstrain(i,k) = edstrain(i,k) + func(i,j) * gausses(j)%strain(k)
            edstress(i,k) = edstress(i,k) + func(i,j) * gausses(j)%stress(k)
!            tdstrain(i,k) = tdstrain(i,k) + func(i,j) * gausses(j)%tstrain(k)
          enddo
        enddo
      enddo
    else if( etype == fe_tri6n ) then
      do i = 1, ni
        do j = 1, ni
          do k = 1, 4
            edstrain(i,k) = edstrain(i,k) + func(i,j) * gausses(j)%strain(k)
            edstress(i,k) = edstress(i,k) + func(i,j) * gausses(j)%stress(k)
!            tdstrain(i,k) = tdstrain(i,k) + func(i,j) * gausses(j)%tstrain(k)
          enddo
        enddo
      enddo
      edstrain(4,1:4) = ( edstrain(1,1:4) + edstrain(2,1:4) ) / 2.0
      edstress(4,1:4) = ( edstress(1,1:4) + edstress(2,1:4) ) / 2.0
      tdstrain(4,1:4) = ( tdstrain(1,1:4) + tdstrain(2,1:4) ) / 2.0
      edstrain(5,1:4) = ( edstrain(2,1:4) + edstrain(3,1:4) ) / 2.0
      edstress(5,1:4) = ( edstress(2,1:4) + edstress(3,1:4) ) / 2.0
      tdstrain(5,1:4) = ( tdstrain(2,1:4) + tdstrain(3,1:4) ) / 2.0
      edstrain(6,1:4) = ( edstrain(3,1:4) + edstrain(1,1:4) ) / 2.0
      edstress(6,1:4) = ( edstress(3,1:4) + edstress(1,1:4) ) / 2.0
      tdstrain(6,1:4) = ( tdstrain(3,1:4) + tdstrain(1,1:4) ) / 2.0
    else if( etype == fe_quad8n ) then
      do i = 1, ni
        ic = 0
        do j = 1, NumOfQuadPoints(etype)
          if( j==1 .or. j==3 .or. j==7 .or. j==9 ) then
            ic = ic + 1
            do k = 1, 4
              edstrain(i,k) = edstrain(i,k) + func(i,ic) * gausses(j)%strain(k)
              edstress(i,k) = edstress(i,k) + func(i,ic) * gausses(j)%stress(k)
!              tdstrain(i,k) = tdstrain(i,k) + func(i,ic) * gausses(j)%tstrain(k)
            enddo
          endif
        enddo
      enddo
      edstrain(5,1:4) = ( edstrain(1,1:4) + edstrain(2,1:4) ) / 2.0
      edstress(5,1:4) = ( edstress(1,1:4) + edstress(2,1:4) ) / 2.0
      tdstrain(5,1:4) = ( tdstrain(1,1:4) + tdstrain(2,1:4) ) / 2.0
      edstrain(6,1:4) = ( edstrain(2,1:4) + edstrain(3,1:4) ) / 2.0
      edstress(6,1:4) = ( edstress(2,1:4) + edstress(3,1:4) ) / 2.0
      tdstrain(6,1:4) = ( tdstrain(2,1:4) + tdstrain(3,1:4) ) / 2.0
      edstrain(7,1:4) = ( edstrain(3,1:4) + edstrain(4,1:4) ) / 2.0
      edstress(7,1:4) = ( edstress(3,1:4) + edstress(4,1:4) ) / 2.0
      tdstrain(7,1:4) = ( tdstrain(3,1:4) + tdstrain(4,1:4) ) / 2.0
      edstrain(8,1:4) = ( edstrain(4,1:4) + edstrain(1,1:4) ) / 2.0
      edstress(8,1:4) = ( edstress(4,1:4) + edstress(1,1:4) ) / 2.0
      tdstrain(8,1:4) = ( tdstrain(4,1:4) + tdstrain(1,1:4) ) / 2.0
    endif
  end subroutine NodalStress_INV2

!----------------------------------------------------------------------*
  subroutine inverse_func( n, a, inv_a )
!----------------------------------------------------------------------*
    use m_fstr
    integer(kind=kint) :: n
    real(kind=kreal)   :: a(:,:), inv_a(:,:)
    integer(kind=kint) :: i, j, k
    real(kind=kreal)   :: buf

    do i = 1, n
      do j = 1, n
        if( i == j ) then
          inv_a(i,j) = 1.0
        else
          inv_a(i,j) = 0.0
        endif
      enddo
    enddo

    do i = 1, n
      buf = 1.0 / a(i,i)
      do j = 1, n
        a(i,j) = a(i,j) * buf
        inv_a(i,j) = inv_a(i,j) *buf
      enddo
      do j = 1, n
        if( i /= j ) then
          buf = a(j,i)
          do k = 1, n
            a(j,k) = a(j,k) - a(i,k) * buf
            inv_a(j,k) = inv_a(j,k) - inv_a(i,k) * buf
          enddo
        endif
      enddo
    enddo
  end subroutine inverse_func

!> Calculate NODAL STRESS of shell elements
!----------------------------------------------------------------------*
  subroutine fstr_NodalStress6D( hecMESH, fstrSOLID )
!----------------------------------------------------------------------*
    use m_fstr
    use m_static_lib
    type (hecmwST_local_mesh) :: hecMESH
    type (fstr_solid)         :: fstrSOLID
!C** local variables
    integer(kind=kint) :: itype, icel, iS, iE, jS, i, j, k, ic_type, nn, isect, ihead, ID_area
    integer(kind=kint) :: nodLOCAL(9)
    real(kind=kreal)   :: ecoord(3,9), edisp(54), strain(9,6), stress(9,6)
    real(kind=kreal)   :: thick
    real(kind=kreal)   :: s11, s22, s33, s12, s23, s13, ps, smises
    real(kind=kreal), allocatable :: ndstrain_plus(:,:), ndstrain_minus(:,:)
    real(kind=kreal), allocatable :: ndstress_plus(:,:), ndstress_minus(:,:)
    integer(kind=kint), allocatable :: nnumber(:)

    allocate ( ndstrain_plus(hecMESH%n_node,7) )
    allocate ( ndstrain_minus(hecMESH%n_node,7) )
    allocate ( ndstress_plus(hecMESH%n_node,7) )
    allocate ( ndstress_minus(hecMESH%n_node,7) )
    allocate ( nnumber(hecMESH%n_node) )
    ndstrain_plus = 0.0d0
    ndstrain_minus = 0.0d0
    ndstress_plus = 0.0d0
    ndstress_minus = 0.0d0
    nnumber = 0

!C +-------------------------------+
!C | according to ELEMENT TYPE     |
!C +-------------------------------+
    do itype = 1, hecMESH%n_elem_type
      iS = hecMESH%elem_type_index(itype-1) + 1
      iE = hecMESH%elem_type_index(itype  )
      ic_type = hecMESH%elem_type_item(itype)
      if( .not. hecmw_is_etype_shell(ic_type) ) cycle
      nn = hecmw_get_max_node( ic_type )
!C** element loop
      do icel = iS, iE
        jS = hecMESH%elem_node_index(icel-1)
        ID_area = hecMESH%elem_ID(icel*2)
        do j = 1, nn
          nodLOCAL(j) = hecMESH%elem_node_item(jS+j)
          ecoord(1,j) = hecMESH%node(3*nodLOCAL(j)-2)
          ecoord(2,j) = hecMESH%node(3*nodLOCAL(j)-1)
          ecoord(3,j) = hecMESH%node(3*nodLOCAL(j)  )
          edisp(6*j-5) = fstrSOLID%unode(6*nodLOCAL(j)-5)
          edisp(6*j-4) = fstrSOLID%unode(6*nodLOCAL(j)-4)
          edisp(6*j-3) = fstrSOLID%unode(6*nodLOCAL(j)-3)
          edisp(6*j-2) = fstrSOLID%unode(6*nodLOCAL(j)-2)
          edisp(6*j-1) = fstrSOLID%unode(6*nodLOCAL(j)-1)
          edisp(6*j  ) = fstrSOLID%unode(6*nodLOCAL(j)  )
        enddo
        isect = hecMESH%section_ID(icel)
        ihead = hecMESH%section%sect_R_index(isect-1)
        thick = hecMESH%section%sect_R_item(ihead+1)
!--- calculate elemental stress and strain
        if( ic_type == 731 .or. ic_type == 741 .or. ic_type == 743 ) then
          call ElementStress_Shell_MITC( ic_type, nn, 6, ecoord, fstrSOLID%elements(icel)%gausses, edisp, &
                                         strain, stress, thick, 1.0d0)
          do j = 1, nn
            i = nodLOCAL(j)
            do k = 1, 6
              ndstrain_plus(i,k) = ndstrain_plus(i,k) + strain(j,k)
              ndstress_plus(i,k) = ndstress_plus(i,k) + stress(j,k)
            enddo
          enddo
          if( ID_area == hecMESH%my_rank ) then
            do j = 1, nn
              do k = 1, 6
                fstrSOLID%ESTRAIN(14*(icel-1)+k) = fstrSOLID%ESTRAIN(14*(icel-1)+k) + strain(j,k)/nn
                fstrSOLID%ESTRESS(14*(icel-1)+k) = fstrSOLID%ESTRESS(14*(icel-1)+k) + stress(j,k)/nn
              enddo
            enddo
            s11 = fstrSOLID%ESTRESS(14*icel-13)
            s22 = fstrSOLID%ESTRESS(14*icel-12)
            s33 = fstrSOLID%ESTRESS(14*icel-11)
            s12 = fstrSOLID%ESTRESS(14*icel-10)
            s23 = fstrSOLID%ESTRESS(14*icel-9 )
            s13 = fstrSOLID%ESTRESS(14*icel-8 )
            ps = ( s11 + s22 + s33 ) / 3.0
            smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
            fstrSOLID%ESTRESS(14*icel-1) = sqrt( 3.0d0 * smises )
          endif
          call ElementStress_Shell_MITC( ic_type, nn, 6, ecoord, fstrSOLID%elements(icel)%gausses, edisp, &
                                         strain, stress, thick, -1.0d0)
          do j = 1, nn
            i = nodLOCAL(j)
            do k = 1, 6
              ndstrain_minus(i,k) = ndstrain_minus(i,k) + strain(i,k)
              ndstress_minus(i,k) = ndstress_minus(i,k) + stress(i,k)
            enddo
            nnumber(i) = nnumber(i) + 1
          enddo
          if( ID_area == hecMESH%my_rank ) then
            do j = 1, nn
              do k = 1, 6
                fstrSOLID%ESTRAIN(14*(icel-1)+k+6) = fstrSOLID%ESTRAIN(14*(icel-1)+k+6) + strain(j,k)/nn
                fstrSOLID%ESTRESS(14*(icel-1)+k+6) = fstrSOLID%ESTRESS(14*(icel-1)+k+6) + stress(j,k)/nn
              enddo
            enddo
            s11 = fstrSOLID%ESTRESS(14*icel-7)
            s22 = fstrSOLID%ESTRESS(14*icel-6)
            s33 = fstrSOLID%ESTRESS(14*icel-5)
            s12 = fstrSOLID%ESTRESS(14*icel-4)
            s23 = fstrSOLID%ESTRESS(14*icel-3)
            s13 = fstrSOLID%ESTRESS(14*icel-2)
            ps = ( s11 + s22 + s33 ) / 3.0
            smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
            fstrSOLID%ESTRESS(14*icel) = sqrt( 3.0d0 * smises )
          endif
        endif
      enddo
    enddo

!C** average over nodes
    do i = 1, hecMESH%n_node
      do j = 1, 6
        ndstrain_plus(i,j) = ndstrain_plus(i,j) / nnumber(i)
        ndstress_plus(i,j) = ndstrain_plus(i,j) / nnumber(i)
        ndstrain_minus(i,j) = ndstrain_minus(i,j) / nnumber(i)
        ndstress_minus(i,j) = ndstrain_minus(i,j) / nnumber(i)
        fstrSOLID%STRAIN(14*(i-1)+j) = ndstrain_plus(i,j)
        fstrSOLID%STRESS(14*(i-1)+j) = ndstress_plus(i,j)
        fstrSOLID%STRAIN(14*(i-1)+j+6) = ndstrain_minus(i,j)
        fstrSOLID%STRESS(14*(i-1)+j+6) = ndstress_minus(i,j)
      enddo
      s11 = fstrSOLID%STRESS(14*i-13)
      s22 = fstrSOLID%STRESS(14*i-12)
      s33 = fstrSOLID%STRESS(14*i-11)
      s12 = fstrSOLID%STRESS(14*i-10)
      s23 = fstrSOLID%STRESS(14*i-9 )
      s13 = fstrSOLID%STRESS(14*i-8 )
      ps = ( s11 + s22 + s33 ) / 3.0
      smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
      fstrSOLID%STRESS(14*i-1) = sqrt( 3.0d0 * smises )
      s11 = fstrSOLID%STRESS(14*i-7)
      s22 = fstrSOLID%STRESS(14*i-6)
      s33 = fstrSOLID%STRESS(14*i-5)
      s12 = fstrSOLID%STRESS(14*i-4)
      s23 = fstrSOLID%STRESS(14*i-3)
      s13 = fstrSOLID%STRESS(14*i-2)
      ps = ( s11 + s22 + s33 ) / 3.0
      smises = 0.5d0 *( (s11-ps)**2 + (s22-ps)**2 + (s33-ps)**2 ) + s12**2 + s23**2+ s13**2
      fstrSOLID%STRESS(14*i) = sqrt( 3.0d0 * smises )
    enddo

    deallocate( ndstrain_plus, ndstrain_minus )
    deallocate( ndstress_plus, ndstress_minus )
    deallocate( nnumber )
  end subroutine fstr_NodalStress6D

end module m_fstr_NodalStress
