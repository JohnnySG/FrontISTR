!-------------------------------------------------------------------------------
! Copyright (c) 2019 FrontISTR Commons
! This software is released under the MIT License, see LICENSE.txt
!-------------------------------------------------------------------------------

!C
!C***
!C*** module hecmw_solver_SR_44i
!C***
!C
module hecmw_solver_SR_44i
contains
  !C
  !C*** SOLVER_SEND_RECV
  !C
  subroutine  HECMW_SOLVE_SEND_RECV_44i                             &
      &                ( N, NEIBPETOT, NEIBPE, STACK_IMPORT, NOD_IMPORT, &
      &                                        STACK_EXPORT, NOD_EXPORT, &
      &                  WS, WR, X, SOLVER_COMM,my_rank)

    use hecmw_util
    implicit real*8 (A-H,O-Z)
    !      include  'mpif.h'
    !      include  'hecmw_config_f.h'

    integer(kind=kint )                , intent(in)   ::  N
    integer(kind=kint )                , intent(in)   ::  NEIBPETOT
    integer(kind=kint ), pointer :: NEIBPE      (:)
    integer(kind=kint ), pointer :: STACK_IMPORT(:)
    integer(kind=kint ), pointer :: NOD_IMPORT  (:)
    integer(kind=kint ), pointer :: STACK_EXPORT(:)
    integer(kind=kint ), pointer :: NOD_EXPORT  (:)
    integer(kind=kint ), dimension(:  ), intent(inout):: WS
    integer(kind=kint ), dimension(:  ), intent(inout):: WR
    integer(kind=kint ), dimension(:  ), intent(inout):: X
    integer(kind=kint )                , intent(in)   ::SOLVER_COMM
    integer(kind=kint )                , intent(in)   :: my_rank

#ifndef HECMW_SERIAL
    integer(kind=kint ), dimension(:,:), allocatable :: sta1
    integer(kind=kint ), dimension(:,:), allocatable :: sta2
    integer(kind=kint ), dimension(:  ), allocatable :: req1
    integer(kind=kint ), dimension(:  ), allocatable :: req2

    integer(kind=kint ), save :: NFLAG
    data NFLAG/0/

    ! local valiables
    integer(kind=kint ) :: neib,istart,inum,k,ii,ierr,nreq1,nreq2
    !C
    !C-- INIT.
    allocate (sta1(MPI_STATUS_SIZE,NEIBPETOT))
    allocate (sta2(MPI_STATUS_SIZE,NEIBPETOT))
    allocate (req1(NEIBPETOT))
    allocate (req2(NEIBPETOT))

    !C
    !C-- SEND
    nreq1=0
    do neib= 1, NEIBPETOT
      istart= STACK_EXPORT(neib-1)
      inum  = STACK_EXPORT(neib  ) - istart
      if (inum==0) cycle
      nreq1=nreq1+1
      do k= istart+1, istart+inum
        ii   = 4*NOD_EXPORT(k)
        WS(4*k-3)= X(ii-3)
        WS(4*k-2)= X(ii-2)
        WS(4*k-1)= X(ii-1)
        WS(4*k  )= X(ii  )
      enddo

      call MPI_ISEND (WS(4*istart+1), 4*inum, MPI_INTEGER,            &
        &                  NEIBPE(neib), 0, SOLVER_COMM, req1(nreq1), ierr)
    enddo

    !C
    !C-- RECEIVE
    nreq2=0
    do neib= 1, NEIBPETOT
      istart= STACK_IMPORT(neib-1)
      inum  = STACK_IMPORT(neib  ) - istart
      if (inum==0) cycle
      nreq2=nreq2+1
      call MPI_IRECV (WR(4*istart+1), 4*inum, MPI_INTEGER,            &
        &                  NEIBPE(neib), 0, SOLVER_COMM, req2(nreq2), ierr)
    enddo

    call MPI_WAITALL (nreq2, req2, sta2, ierr)

    do neib= 1, NEIBPETOT
      istart= STACK_IMPORT(neib-1)
      inum  = STACK_IMPORT(neib  ) - istart
      do k= istart+1, istart+inum
        ii   = 4*NOD_IMPORT(k)
        X(ii-3)= WR(4*k-3)
        X(ii-2)= WR(4*k-2)
        X(ii-1)= WR(4*k-1)
        X(ii  )= WR(4*k  )
      enddo
    enddo

    call MPI_WAITALL (nreq1, req1, sta1, ierr)
    deallocate (sta1, sta2, req1, req2)
#endif
  end subroutine hecmw_solve_send_recv_44i
end module     hecmw_solver_SR_44i
