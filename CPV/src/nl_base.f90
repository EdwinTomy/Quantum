!
! Copyright (C) 2002-2005 FPMD-CPV groups
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
   SUBROUTINE beta_eigr_x ( beigr, nspmn, nspmx, eigr, pptype_ )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     beigr(ig,iv)=
      !         = [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* 
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE ions_base,  only : nat, nsp, ityp
      USE gvecw,      only : ngw
      USE uspp,       only : nkb, nhtol, beta, indv_ijkb0
      USE uspp_param, only : nh, upf, nhm
      !
      USE gvect, ONLY : gstart
!
      implicit none

      integer,     intent(in)  :: nspmn, nspmx
      complex(DP), intent(in)  :: eigr( :, : )
      complex(DP), intent(out) :: beigr( :, : )
      INTEGER,     INTENT(IN), OPTIONAL  :: pptype_
      ! pptype_: pseudo type to process: 0 = all, 1 = norm-cons, 2 = ultra-soft
      !
      integer   :: ig, is, iv, ia, l, inl
      complex(DP) :: cfact(4)
      integer :: pptype
      LOGICAL :: ok1, ok2
      !
      call start_clock( 'beta_eigr' )

      IF( PRESENT( pptype_ ) ) THEN
         pptype = pptype_
      ELSE
         pptype = 0
      END IF

!$omp parallel default(none), &
!$omp shared(nat,ngw,nh,nhtol,beigr,beta,eigr,ityp,pptype,nspmn,nspmx,upf,gstart,indv_ijkb0), &
!$omp private(is,ia,iv,inl,l,cfact,ig,ok1,ok2)

      !if (l == 0) then
      cfact(1) =   cmplx( 1.0_dp , 0.0_dp )
      !else if (l == 1) then
      cfact(2) = - cmplx( 0.0_dp , 1.0_dp )
      !else if (l == 2) then
      cfact(3) = - cmplx( 0.0_dp , 1.0_dp )
      cfact(3) = cfact(3) * cfact(3)
      !else if (l == 3) then
      cfact(4) = - cmplx( 0.0_dp , 1.0_dp )
      cfact(4) = cfact(4) * cfact(4) * cfact(4)
      !endif

!$omp do
      DO ia = 1, nat
         is  = ityp(ia)
         inl = indv_ijkb0(ia)
         !
         ok1 = .NOT. ( pptype == 1 .AND. upf(is)%tvanp )
         ok2 = .NOT. ( pptype == 2 .AND. .NOT. upf(is)%tvanp )
         IF( ok1 .AND. ok2 .AND. ( is >= nspmn .AND. is <= nspmx ) ) THEN
              !
              do iv = 1, nh( is )
                !
                l = nhtol( iv, is )
                !
                !  q = 0   component (with weight 1.0)  !  kept only with gstart = 2
                !
                beigr( 1, iv + inl ) = cfact(l+1) * beta(1,iv,is) * eigr(1,ia)
                !
                !   q > 0   components (with weight 2.0)
                !
                do ig = gstart, ngw
                  beigr( ig, iv + inl ) = 2.0d0 * cfact(l+1) * beta(ig,iv,is) * eigr(ig,ia)
                end do
                !
              end do
              !
         ELSE
            DO iv = 1, nh( is )
               beigr(:,iv+inl) = 0.0d0
            END DO
         END IF
      END DO
!$omp end do
!$omp end parallel

      call stop_clock( 'beta_eigr' )

      RETURN
   END SUBROUTINE beta_eigr_x
!-----------------------------------------------------------------------
!
#if defined(__CUDA)
!
!-----------------------------------------------------------------------
   SUBROUTINE beta_eigr_gpu_x ( beigr_d, nspmn, nspmx, eigr, pptype_ )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     beigr(ig,iv)=
      !         = [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* 
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE ions_base,  only : nat, nsp, ityp
      USE gvecw,      only : ngw
      USE uspp,       only : nkb, nhtol, beta, indv_ijkb0
      USE uspp_param, only : nh, upf, nhm
      USE gvect, ONLY : gstart
      USE cudafor
!
      implicit none

      integer,     intent(in)  :: nspmn, nspmx
      complex(DP), intent(in)  :: eigr( :, : )
      complex(DP), DEVICE, intent(out) :: beigr_d( :, : )
      INTEGER,     INTENT(IN), OPTIONAL  :: pptype_
      ! pptype_: pseudo type to process: 0 = all, 1 = norm-cons, 2 = ultra-soft
      !
      integer   :: ig, is, iv, ia, l, inl
      complex(DP) :: cfact(4), c2, c1
      COMPLEX(DP), ALLOCATABLE :: beigr(:,:)
      integer :: pptype
      LOGICAL :: ok1, ok2
      !
      call start_clock( 'beta_eigr' )

      IF( PRESENT( pptype_ ) ) THEN
         pptype = pptype_
      ELSE
         pptype = 0
      END IF

      ALLOCATE( beigr, MOLD=beigr_d )

!$omp parallel default(none), &
!$omp shared(nat,ngw,nh,nhtol,beigr,beta,eigr,ityp,pptype,nspmn,nspmx,upf,gstart,indv_ijkb0), &
!$omp private(is,ia,iv,inl,l,cfact,ig,ok1,ok2,c1,c2)

      ! (l == 0) 
      cfact(1) =   cmplx( 1.0_dp , 0.0_dp )
      ! (l == 1) 
      cfact(2) = - cmplx( 0.0_dp , 1.0_dp )
      ! (l == 2) 
      cfact(3) = - cmplx( 1.0_dp , 0.0_dp )
      ! (l == 3) 
      cfact(4) =   cmplx( 0.0_dp , 1.0_dp )

!$omp do
      DO ia = 1, nat
         is  = ityp(ia)
         inl = indv_ijkb0(ia)
         !
         ok1 = .NOT. ( pptype == 1 .AND. upf(is)%tvanp )
         ok2 = .NOT. ( pptype == 2 .AND. .NOT. upf(is)%tvanp )
         IF( ok1 .AND. ok2 .AND. ( is >= nspmn .AND. is <= nspmx ) ) THEN
              !
              do iv = 1, nh( is )
                !
                l = nhtol( iv, is )
                c1 = cfact(l+1)
                c2 = 2.0d0 * c1
                !
                !  q = 0   component (with weight 1.0) !  kept only with gstart = 2
                !
                beigr( 1, iv + inl ) = c1 * beta(1,iv,is) * eigr(1,ia)
                !
                !   q > 0   components (with weight 2.0)
                !
                do ig = gstart, ngw
                  beigr( ig, iv + inl ) = c2 * beta(ig,iv,is) * eigr(ig,ia)
                end do
                !
              end do
              !
         ELSE
            DO iv = 1, nh( is )
               beigr(:,iv+inl) = 0.0d0
            END DO
         END IF
      END DO
!$omp end do
!$omp end parallel

      beigr_d = beigr
      DEALLOCATE( beigr )

      call stop_clock( 'beta_eigr' )

      RETURN
   END SUBROUTINE beta_eigr_gpu_x
!-----------------------------------------------------------------------
!
#endif
!
!-----------------------------------------------------------------------
   subroutine nlsm1us_x ( n, beigr, c, becp )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     becp(ia,n,iv,is)=
      !         = sum_g [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* c(g,n)
      !         = delta_l0 beta(g=0,iv,is) c(g=0,n)
      !          +sum_g> beta(g,iv,is) 2 re[(i)**l e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE mp,         ONLY : mp_sum
      USE mp_global,  ONLY : nproc_bgrp, intra_bgrp_comm
      USE gvecw,      only : ngw
      USE uspp,       only : nkb
!
      implicit none

      integer,     intent(in)  :: n
      complex(DP), intent(in)  :: beigr( :, : ), c( :, : )
      real(DP),    intent(out) :: becp( :, : )
      !
      call start_clock( 'nlsm1us' )

      IF( ngw > 0 .AND. nkb > 0 ) THEN
         CALL dgemm( 'T', 'N', nkb, n, 2*ngw, 1.0d0, beigr, 2*ngw, c, 2*ngw, 0.0d0, becp, nkb )
      END IF

      IF( nproc_bgrp > 1 ) THEN
        CALL mp_sum( becp, intra_bgrp_comm )
      END IF

      call stop_clock( 'nlsm1us' )

      return
   end subroutine nlsm1us_x
!-----------------------------------------------------------------------
!
#if defined(__CUDA)
!
!-----------------------------------------------------------------------
   subroutine nlsm1us_gpu_x ( n, beigr, c, becp )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     becp(ia,n,iv,is)=
      !         = sum_g [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* c(g,n)
      !         = delta_l0 beta(g=0,iv,is) c(g=0,n)
      !          +sum_g> beta(g,iv,is) 2 re[(i)**l e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE mp,         ONLY : mp_sum
      USE mp_global,  ONLY : nproc_bgrp, intra_bgrp_comm
      USE gvecw,      only : ngw
      USE uspp,       only : nkb
      USE cudafor
      USE cublas
!
      implicit none

      integer,     intent(in)  :: n
      complex(DP), device, intent(in)  :: c( :, : )
      complex(DP), device, intent(in)  :: beigr( :, : )
      real(DP),    device, intent(out) :: becp( :, : )
      !
      call start_clock( 'nlsm1us' )

      IF( ngw > 0 .AND. nkb > 0 ) THEN
         CALL MYDGEMM( 'T', 'N', nkb, n, 2*ngw, 1.0d0, beigr, 2*ngw, c, 2*ngw, 0.0d0, becp, nkb )
      END IF

      IF( nproc_bgrp > 1 ) THEN
        CALL mp_sum( becp, intra_bgrp_comm )
      END IF

      call stop_clock( 'nlsm1us' )

      return
   end subroutine nlsm1us_gpu_x
!-----------------------------------------------------------------------
!
#endif
!
!-----------------------------------------------------------------------
   subroutine nlsm1_x ( n, nspmn, nspmx, eigr, c, becp, pptype_ )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     becp(ia,n,iv,is)=
      !         = sum_g [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* c(g,n)
      !         = delta_l0 beta(g=0,iv,is) c(g=0,n)
      !          +sum_g> beta(g,iv,is) 2 re[(i)**l e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE mp,         ONLY : mp_sum
      USE mp_global,  ONLY : nproc_bgrp, intra_bgrp_comm
      USE ions_base,  only : nat, nsp, ityp
      USE gvecw,      only : ngw
      USE uspp,       only : nkb, nhtol, beta, indv_ijkb0
      USE uspp_param, only : nh, upf, nhm
      USE gvect,      ONLY : gstart
      USE cp_interfaces, only : beta_eigr
!
      implicit none

      integer,     intent(in)  :: n, nspmn, nspmx
      complex(DP), intent(in)  :: eigr( :, : ), c( :, : )
      real(DP), intent(out) :: becp( :, : )
      INTEGER,     INTENT(IN), OPTIONAL  :: pptype_
      ! pptype_: pseudo type to process: 0 = all, 1 = norm-cons, 2 = ultra-soft
      !
      integer   :: ig, is, iv, ia, l, inl
      real(DP), allocatable :: becps( :, : )
      complex(DP), allocatable :: wrk2( :, : )
      complex(DP) :: cfact
      integer :: pptype
      !
      call start_clock( 'nlsm1' )

      IF( PRESENT( pptype_ ) ) THEN
         pptype = pptype_
      ELSE
         pptype = 0
      END IF

      allocate( wrk2( ngw, nkb ) ) 
      allocate( becps( SIZE(becp,1), SIZE(becp,2) ) ) 
 
      CALL beta_eigr ( wrk2, nspmn, nspmx, eigr, pptype_ )

      IF( ngw > 0 .AND. nkb > 0 ) THEN
         CALL dgemm( 'T', 'N', nkb, n, 2*ngw, 1.0d0, wrk2, 2*ngw, c, 2*ngw, 0.0d0, becps, nkb )
      END IF

      DEALLOCATE( wrk2 )

      IF( nproc_bgrp > 1 ) THEN
        CALL mp_sum( becps, intra_bgrp_comm )
      END IF
      do is = nspmn, nspmx
        IF( pptype == 2 .AND. .NOT. upf(is)%tvanp ) CYCLE
        IF( pptype == 1 .AND. upf(is)%tvanp ) CYCLE
          DO ia = 1, nat
            IF( ityp(ia) == is ) THEN
              inl = indv_ijkb0(ia)
              do iv = 1, nh( is )
                becp(inl+iv,:) = becps( inl+iv, : )
              end do
            END IF
          end do
      end do
              !
      DEALLOCATE( becps )

      call stop_clock( 'nlsm1' )

      return
   end subroutine nlsm1_x
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
   subroutine nlsm1nc_x ( n, eigr, c, becp )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     becp(ia,n,iv,is)=
      !         = sum_g [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* c(g,n)
      !         = delta_l0 beta(g=0,iv,is) c(g=0,n)
      !          +sum_g> beta(g,iv,is) 2 re[(i)**l e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE mp,         ONLY : mp_sum
      USE mp_global,  ONLY : nproc_bgrp, intra_bgrp_comm
      USE ions_base,  only : nat, nsp, ityp
      USE gvecw,      only : ngw
      USE uspp,       only : nkb, nhtol, beta, indv_ijkb0
      USE uspp_param, only : nh, upf, nhm
      USE cp_interfaces, only : beta_eigr
!
      IMPLICIT NONE
      INTEGER,     INTENT(IN)  :: n
      COMPLEX(DP), INTENT(IN)  :: eigr( :, : )
      COMPLEX(DP), INTENT(IN)  :: c( :, : )
      REAL(DP),    INTENT(OUT) :: becp( :, : )
      !
      integer   :: is, iv, ia, inl
      real(DP), allocatable :: becps( :, : )
      complex(DP), allocatable :: wrk2( :, : )
      LOGICAL :: nothing_to_do
      !
      call start_clock( 'nlsm1' )

      nothing_to_do = .TRUE.
      do is = 1, nsp
        IF( .NOT. upf(is)%tvanp ) THEN
          nothing_to_do = .FALSE.
        END IF
      END DO
      IF( nothing_to_do ) GO TO 100

      allocate( wrk2( ngw, nkb ) ) 
      allocate( becps( SIZE(becp,1), SIZE(becp,2) ) ) 
 
      CALL beta_eigr ( wrk2, 1, nsp, eigr, 1 )

      IF( ngw > 0 .AND. nkb > 0 ) THEN
         CALL dgemm( 'T', 'N', nkb, n, 2*ngw, 1.0d0, wrk2, 2*ngw, c, 2*ngw, 0.0d0, becps, nkb )
      END IF

      DEALLOCATE( wrk2 )

      IF( nproc_bgrp > 1 ) THEN
        CALL mp_sum( becps, intra_bgrp_comm )
      END IF
      do is = 1, nsp
        IF( .NOT. upf(is)%tvanp ) THEN
          DO ia = 1, nat
            IF( ityp(ia) == is ) THEN
              inl = indv_ijkb0(ia)
              do iv = 1, nh( is )
                becp(inl+iv,:) = becps( inl+iv, : )
              end do
            END IF
          end do
        END IF
      end do
              !
      DEALLOCATE( becps )

100   CONTINUE

      call stop_clock( 'nlsm1' )

      return
   end subroutine nlsm1nc_x
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
   subroutine nlsm1all_x ( n, eigr, c, becp )
!-----------------------------------------------------------------------

      !     computes: the array becp
      !     becp(ia,n,iv,is)=
      !         = sum_g [(-i)**l beta(g,iv,is) e^(-ig.r_ia)]^* c(g,n)
      !         = delta_l0 beta(g=0,iv,is) c(g=0,n)
      !          +sum_g> beta(g,iv,is) 2 re[(i)**l e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of c*(g)=c(-g)  (g> see routine ggen)
      !     input : beta(ig,l,is), eigr, c
      !     output: becp as parameter
      !
      USE kinds,      ONLY : DP
      USE mp,         ONLY : mp_sum
      USE mp_global,  ONLY : nproc_bgrp, intra_bgrp_comm
      USE ions_base,  only : nat, nsp, ityp
      USE gvecw,      only : ngw
      USE uspp,       only : nkb, nhtol, beta, indv_ijkb0
      USE uspp_param, only : nh, upf, nhm
      USE cp_interfaces, only : beta_eigr
!
      IMPLICIT NONE
      INTEGER,     INTENT(IN)  :: n
      COMPLEX(DP), INTENT(IN)  :: eigr( :, : )
      COMPLEX(DP), INTENT(IN)  :: c( :, : )
      REAL(DP),    INTENT(OUT) :: becp( :, : )
      !
      integer   :: is, iv, ia, inl
      real(DP), allocatable :: becps( :, : )
      complex(DP), allocatable :: wrk2( :, : )
      !
      call start_clock( 'nlsm1' )

      allocate( wrk2( ngw, nkb ) ) 
 
      CALL beta_eigr ( wrk2, 1, nsp, eigr, 0 )

      IF( ngw > 0 .AND. nkb > 0 ) THEN
         CALL dgemm( 'T', 'N', nkb, n, 2*ngw, 1.0d0, wrk2, 2*ngw, c, 2*ngw, 0.0d0, becp, SIZE(becp,1) )
      END IF

      DEALLOCATE( wrk2 )

      IF( nproc_bgrp > 1 ) THEN
        CALL mp_sum( becp, intra_bgrp_comm )
      END IF

      call stop_clock( 'nlsm1' )

      return
   end subroutine nlsm1all_x
!-----------------------------------------------------------------------
!-------------------------------------------------------------------------
   subroutine g_beta_eigr_x( gbeigr, eigr )
!-----------------------------------------------------------------------

      !     computes: 
      !      g_k beta(g,iv,is) (i)**(l+1) e^(ig.r_ia)
      !
 
      USE kinds,      ONLY : DP
      use ions_base,  only : nsp, ityp, nat
      use uspp,       only : nhtol, beta, indv_ijkb0
      use uspp_param, only : nh, upf
      use cell_base,  only : tpiba
      use gvect,      only : g, gstart
      USE gvecw,      only : ngw
!
      implicit none
    
      complex(DP), intent(in)  :: eigr(:,:)
      complex(DP), intent(out) :: gbeigr(:,:,:)
      !
      integer  :: ig, is, iv, ia, k, l, inl
      complex(DP) :: cfact(4)
!
      call start_clock( 'g_beta_eigr' )
!
!$omp parallel default(none), &
!$omp shared(nat,ngw,nh,nhtol,gbeigr,beta,eigr,ityp,g,gstart,indv_ijkb0,tpiba), &
!$omp private(is,ia,iv,inl,l,cfact,ig,k)

      ! compute (-i)^(l+1)
      !
      !if (l == 0) then
      cfact(1) = - cmplx( 0.0_dp , 1.0_dp )
      !else if (l == 1) then
      cfact(2) = - cmplx( 0.0_dp , 1.0_dp )
      cfact(2) = cfact(2) * cfact(2)
      !else if (l == 2) then
      cfact(3) = - cmplx( 0.0_dp , 1.0_dp )
      cfact(3) = cfact(3) * cfact(3) * cfact(3)
      !else if (l == 3) then
      cfact(4) =   cmplx( 1.0_dp , 0.0_dp )
      !endif
      cfact(1) = cfact(1) * tpiba
      cfact(2) = cfact(2) * tpiba
      cfact(3) = cfact(3) * tpiba
      cfact(4) = cfact(4) * tpiba

!$omp do collapse(2)
      DO ia = 1, nat
         DO k = 1, 3
            is = ityp(ia) 
            inl = indv_ijkb0(ia)
            do iv=1,nh(is)
               !
               !     order of states:  s_1  p_x1  p_z1  p_y1  s_2  p_x2  p_z2  p_y2
               !
               l=nhtol(iv,is)
               !    q = 0   component (with weight 1.0)
               gbeigr(1,iv+inl,k) = cfact(l+1) * g(k,1) * beta(1,iv,is) * eigr(1,ia)
               !    q > 0   components (with weight 2.0)
               do ig=gstart,ngw
                  gbeigr(ig,iv+inl,k) = cfact(l+1) * 2.0d0 * g(k,ig) * beta(ig,iv,is) * eigr(ig,ia)
               end do
            end do
         end do
      end do
!$omp end do
!$omp end parallel

      call stop_clock( 'g_beta_eigr' )
!
      return
   end subroutine g_beta_eigr_x
!-----------------------------------------------------------------------

!-------------------------------------------------------------------------
   subroutine nlsm2_bgrp_x( ngw, nkb, eigr, c_bgrp, becdr_bgrp, nbspx_bgrp, nbsp_bgrp )
!-----------------------------------------------------------------------

      !     computes: the array becdr
      !     becdr(ia,n,iv,is,k)
      !      =2.0 sum_g> g_k beta(g,iv,is) re[ (i)**(l+1) e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of  c*(g)=c(-g)  (g> see routine ggen)
      !     input : eigr, c
      !     output: becdr
      !
 
      USE kinds,      ONLY : DP
      use ions_base,  only : nsp, ityp, nat
      use uspp,       only : nhtol, beta, indv_ijkb0
      use uspp_param, only : nh, upf
      use cell_base,  only : tpiba
      use mp,         only : mp_sum
      use mp_global,  only : nproc_bgrp, intra_bgrp_comm
      use gvect,      only : g, gstart
      USE cp_interfaces, only : g_beta_eigr
!
      implicit none
    
      integer,     intent(in)  :: ngw, nkb, nbspx_bgrp, nbsp_bgrp
      complex(DP), intent(in)  :: eigr(:,:), c_bgrp(:,:)
      real(DP),    intent(out) :: becdr_bgrp(:,:,:)
      !
      complex(DP), allocatable :: wrk2(:,:,:)
      !
      integer  :: ig, is, iv, ia, k, l, inl
      complex(DP) :: cfact
!
      call start_clock( 'nlsm2' )

      allocate( wrk2( ngw, nkb, 3 ) )
   
      CALL g_beta_eigr( wrk2, eigr )
!
      DO k = 1, 3
         !
         IF( ngw > 0 .AND. nkb > 0 ) THEN
            CALL dgemm( 'T', 'N', nkb, nbsp_bgrp, 2*ngw, 1.0d0, wrk2(1,1,k), 2*ngw, &
                 c_bgrp, 2*ngw, 0.0d0, becdr_bgrp( 1, 1, k ), nkb )
         END IF

      end do

      deallocate( wrk2 )

      IF( nproc_bgrp > 1 ) THEN
         CALL mp_sum( becdr_bgrp, intra_bgrp_comm )
      END IF

      call stop_clock( 'nlsm2' )
!
      return
   end subroutine nlsm2_bgrp_x
!-----------------------------------------------------------------------

#if defined (__CUDA)
!-------------------------------------------------------------------------
   subroutine nlsm2_bgrp_gpu_x( ngw, nkb, eigr, c_bgrp, becdr_bgrp, nbspx_bgrp, nbsp_bgrp )
!-----------------------------------------------------------------------

      !     computes: the array becdr
      !     becdr(ia,n,iv,is,k)
      !      =2.0 sum_g> g_k beta(g,iv,is) re[ (i)**(l+1) e^(ig.r_ia) c(g,n)]
      !
      !     routine makes use of  c*(g)=c(-g)  (g> see routine ggen)
      !     input : eigr, c
      !     output: becdr
      !
 
      USE kinds,      ONLY : DP
      use ions_base,  only : nsp, ityp, nat
      use uspp,       only : nhtol, beta, indv_ijkb0
      use uspp_param, only : nh, upf
      use cell_base,  only : tpiba
      use mp,         only : mp_sum
      use mp_global,  only : nproc_bgrp, intra_bgrp_comm
      use gvect,      only : g, gstart
      USE cp_interfaces, only : g_beta_eigr
      USE device_util_m, ONLY : dev_memcpy
      USE cudafor
      USE cublas
!
      implicit none
    
      integer,     intent(in)  :: ngw, nkb, nbspx_bgrp, nbsp_bgrp
      complex(DP), intent(in), DEVICE :: c_bgrp(:,:)
      complex(DP), intent(in)  :: eigr(:,:)
      real(DP),    intent(out) :: becdr_bgrp(:,:,:)
      !
      complex(DP), allocatable :: wrk2(:,:,:)
      complex(DP), allocatable, DEVICE :: wrk2_d(:,:,:)
      real(DP), allocatable, DEVICE :: becdr_d(:,:)
      !
      integer  :: ig, is, iv, ia, k, l, inl, info
      complex(DP) :: cfact
!
      call start_clock( 'nlsm2' )

      allocate( wrk2( ngw, nkb, 3 ), STAT = info )
      IF( info /= 0 ) &
         CALL errore( ' nlsm2 ', ' allocating wrk2 ', ABS( info ) )
   
      CALL g_beta_eigr( wrk2, eigr )
!
      ALLOCATE( wrk2_d, SOURCE=wrk2, STAT = info )
      IF( info /= 0 ) &
         CALL errore( ' nlsm2 ', ' allocating wrk2_d ', ABS( info ) )
      ALLOCATE( becdr_d( SIZE( becdr_bgrp, 1 ), SIZE( becdr_bgrp, 2 ) ), STAT=info ) 
      IF( info /= 0 ) &
         CALL errore( ' nlsm2 ', ' allocating becdr_d ', ABS( info ) )

      DO k = 1, 3
         !
         IF( ngw > 0 .AND. nkb > 0 ) THEN
            CALL MYDGEMM( 'T', 'N', nkb, nbsp_bgrp, 2*ngw, 1.0d0, wrk2_d(1,1,k), 2*ngw, &
                 c_bgrp, 2*ngw, 0.0d0, becdr_d, nkb )
            CALL dev_memcpy( becdr_bgrp(:,:,k), becdr_d )
         END IF

      end do

      DEALLOCATE( becdr_d )
      DEALLOCATE( wrk2_d )
      deallocate( wrk2 )

      IF( nproc_bgrp > 1 ) THEN
         CALL mp_sum( becdr_bgrp, intra_bgrp_comm )
      END IF

      call stop_clock( 'nlsm2' )
!
      return
   end subroutine nlsm2_bgrp_gpu_x
!-----------------------------------------------------------------------
#endif

!-----------------------------------------------------------------------
   SUBROUTINE ennl_x( ennl_val, rhovan, bec_bgrp )
!-----------------------------------------------------------------------
      !
      ! calculation of nonlocal potential energy term and array rhovan
      !
      use kinds,          only : DP
      use uspp_param,     only : nh, upf
      use uspp,           only : dvan, indv_ijkb0
      use electrons_base, only : nbsp_bgrp, nspin, ispin_bgrp, f_bgrp, nbspx_bgrp
      use ions_base,      only : nsp, nat, ityp
      !
      implicit none
      !
      ! input
      !
      real(DP), intent(out) :: ennl_val
      real(DP), intent(out) :: rhovan( :, :, : )
      real(DP), intent(in)  :: bec_bgrp( :, : )
      !
      ! local
      !
      real(DP) :: sumt, sums(2), ennl_t
      integer  :: is, iv, jv, ijv, inl, jnl, ia, iss, i, indv
      INTEGER  :: omp_get_num_threads
      !
      ennl_t = 0.d0  
      !
!$omp parallel num_threads(min(4,omp_get_num_threads())) default(none) &
!$omp shared(nat,ityp,indv_ijkb0,nh,nbsp_bgrp,ispin_bgrp,f_bgrp,bec_bgrp,rhovan,dvan,nspin,ennl_t) &
!$omp private(ia,is,indv,iv,inl,jv,ijv,jnl,sums,iss,i,sumt)
!$omp do reduction(+:ennl_t)
      do ia = 1, nat
         is   = ityp(ia)
         indv = indv_ijkb0(ia)
         do iv = 1, nh(is)
            inl = indv + iv
            do jv = iv, nh(is)
               ijv = (jv-1)*jv/2 + iv
               jnl = indv + jv
               sums = 0.d0
               do i = 1, nbsp_bgrp
                  iss = ispin_bgrp(i)
                  sums(iss) = sums(iss) + f_bgrp(i) * bec_bgrp(inl,i) * bec_bgrp(jnl,i)
               end do
               sumt = 0.d0
               do iss = 1, nspin
                  rhovan( ijv, ia, iss ) = sums( iss )
                  sumt = sumt + sums( iss )
               end do
               if( iv .ne. jv ) sumt = 2.d0 * sumt
               ennl_t = ennl_t + sumt * dvan( jv, iv, is)
            end do
         end do
      end do
!$omp end do
!$omp end parallel
      !
      ennl_val = ennl_t
      !
      return
   end subroutine ennl_x
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
   subroutine calrhovan_x( rhovan, bec, iwf )
!-----------------------------------------------------------------------
      !
      ! calculation of rhovan relative to state iwf
      !
      use kinds,          only : DP
      use uspp_param,     only : nh
      use uspp,           only : indv_ijkb0
      use electrons_base, only : ispin, f
      use ions_base,      only : nat, ityp
      !
      implicit none
      !
      ! input
      !
      real(DP), intent(out) :: rhovan( :, :, : )
      real(DP), intent(in) :: bec( :, : )
      integer, intent(in) :: iwf
      !
      ! local
      !
      integer   :: is, iv, jv, ijv, inl, jnl, ia, iss
      !
      iss = ispin(iwf)
      !
      do ia = 1, nat
         is = ityp(ia)
         do iv = 1, nh(is)
            do jv = iv, nh(is)
               ijv = (jv-1)*jv/2 + iv
               inl = indv_ijkb0(ia) + iv
               jnl = indv_ijkb0(ia) + jv
               rhovan( ijv, ia, iss ) = f(iwf) * bec(inl,iwf) * bec(jnl,iwf)
            end do
         end do
      end do
      !
      return
   end subroutine calrhovan_x
!-----------------------------------------------------------------------



!-----------------------------------------------------------------------
   subroutine calbec_x ( nspmn, nspmx, eigr, c, bec, pptype_ )
!-----------------------------------------------------------------------

      !     this routine calculates array bec
      !
      !        < psi_n | beta_i,i > = c_n(0) beta_i,i(0) +
      !                 2 sum_g> re(c_n*(g) (-i)**l beta_i,i(g) e^-ig.r_i)
      !
      !     routine makes use of c(-g)=c*(g)  and  beta(-g)=beta*(g)
      !
      
      USE kinds,          ONLY : DP
      use electrons_base, only : nbsp
      use cp_interfaces,  only : nlsm1
!
      implicit none
      !
      integer,     intent(in)  :: nspmn, nspmx
      real(DP),    intent(out) :: bec( :, : )
      complex(DP), intent(in)  :: c( :, : ), eigr( :, : )
      INTEGER,     INTENT(IN), OPTIONAL  :: pptype_

      ! local variables
!
      call start_clock( 'calbec' )
      !
      call nlsm1( nbsp, nspmn, nspmx, eigr, c, bec, pptype_ )
!
      call stop_clock( 'calbec' )
!
      return
   end subroutine calbec_x
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
   subroutine calbec_bgrp_x ( eigr, c_bgrp, bec_bgrp )
!-----------------------------------------------------------------------

      !     this routine calculates array bec
      !
      !        < psi_n | beta_i,i > = c_n(0) beta_i,i(0) +
      !                 2 sum_g> re(c_n*(g) (-i)**l beta_i,i(g) e^-ig.r_i)
      !
      !     routine makes use of c(-g)=c*(g)  and  beta(-g)=beta*(g)
      !

      USE kinds,          ONLY : DP
      use electrons_base, only : nbsp_bgrp
      use cp_interfaces,  only : nlsm1all
!
      implicit none
      real(DP),    intent(out) :: bec_bgrp( :, : )
      complex(DP), intent(in)  :: c_bgrp( :, : ), eigr( :, : )
!
      call start_clock( 'calbec' )
      call nlsm1all( nbsp_bgrp, eigr, c_bgrp, bec_bgrp )
      call stop_clock( 'calbec' )
!
      return
   end subroutine calbec_bgrp_x

!-----------------------------------------------------------------------
   subroutine calbec_nc_x ( eigr, c_bgrp, bec_bgrp )
!-----------------------------------------------------------------------

      !     this routine calculates array bec
      !
      !        < psi_n | beta_i,i > = c_n(0) beta_i,i(0) +
      !                 2 sum_g> re(c_n*(g) (-i)**l beta_i,i(g) e^-ig.r_i)
      !
      !     routine makes use of c(-g)=c*(g)  and  beta(-g)=beta*(g)
      !

      USE kinds,          ONLY : DP
      use electrons_base, only : nbsp_bgrp
      use cp_interfaces,  only : nlsm1nc
!
      implicit none
      !
      real(DP),    intent(out) :: bec_bgrp( :, : )
      complex(DP), intent(in)  :: c_bgrp( :, : ), eigr( :, : )
!
      call start_clock( 'calbec' )
      call nlsm1nc( nbsp_bgrp, eigr, c_bgrp, bec_bgrp )
      call stop_clock( 'calbec' )
!
      return
   end subroutine calbec_nc_x

!-----------------------------------------------------------------------
SUBROUTINE dbeta_eigr_x( dbeigr, eigr )
  !-----------------------------------------------------------------------
  !
  USE kinds,      ONLY : DP
  use ions_base,  only : nat, ityp
  use uspp,       only : nhtol, nkb, dbeta, indv_ijkb0
  use uspp_param, only : nh, nhm
  use gvect,      only : gstart
  use gvecw,      only : ngw
  !
  implicit none
  !
  include 'laxlib.fh'
  !
  complex(DP), intent(out) :: dbeigr( :, :, :, : )
  complex(DP), intent(in)  :: eigr(:,:)
  !
  integer   :: ig, is, iv, ia, l, inl, i, j
  complex(DP) :: cfact(4)
  !
  !if (l == 0) then
  cfact(1) =   cmplx( 1.0_dp , 0.0_dp )
  !else if (l == 1) then
  cfact(2) = - cmplx( 0.0_dp , 1.0_dp )
  !else if (l == 2) then
  cfact(3) = - cmplx( 0.0_dp , 1.0_dp )
  cfact(3) = cfact(3) * cfact(3)
  !else if (l == 3) then
  cfact(4) = - cmplx( 0.0_dp , 1.0_dp )
  cfact(4) = cfact(4) * cfact(4) * cfact(4)
  !endif

  do j=1,3
     do i=1,3
        do ia = 1, nat
           is = ityp(ia) 
           inl = indv_ijkb0(ia)
           do iv=1,nh(is)
              l=nhtol(iv,is)
              !     q = 0   component (with weight 1.0)
              dbeigr(1,iv+inl,i,j)= cfact(l+1)*dbeta(1,iv,is,i,j)*eigr(1,ia)
              !     q > 0   components (with weight 2.0)
              do ig = gstart, ngw
                 dbeigr(ig,iv+inl,i,j) = 2.0d0*cfact(l+1)*dbeta(ig,iv,is,i,j)*eigr(ig,ia)
              end do
           end do
        end do
     end do
  end do
  !
  return
end subroutine dbeta_eigr_x
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
SUBROUTINE caldbec_bgrp_x( eigr, c_bgrp, dbec, idesc )
  !-----------------------------------------------------------------------
  !
  !     this routine calculates array dbec, derivative of bec:
  !
  !        < psi_n | beta_i,i > = c_n(0) beta_i,i(0) +
  !                 2 sum_g> re(c_n*(g) (-i)**l beta_i,i(g) e^-ig.r_i)
  !
  !     with respect to cell parameters h
  !
  !     routine makes use of c(-g)=c*(g)  and  beta(-g)=beta*(g)
  !
  USE kinds,      ONLY : DP
  use mp,         only : mp_sum
  use mp_global,  only : nproc_bgrp, intra_bgrp_comm, inter_bgrp_comm, nbgrp
  use ions_base,  only : nat, ityp
  use uspp,       only : nhtol, nkb, dbeta, indv_ijkb0
  use uspp_param, only : nh, nhm
  use gvect,      only : gstart
  use gvecw,      only : ngw
  use electrons_base, only : nspin, iupdwn, nupdwn, nbspx_bgrp, iupdwn_bgrp, nupdwn_bgrp, &
                             ibgrp_g2l, i2gupdwn_bgrp, nbspx, nbsp_bgrp
  use cp_interfaces,  only : dbeta_eigr
  !
  implicit none
  !
  include 'laxlib.fh'
  !
  complex(DP), intent(in)  :: c_bgrp( :, : )
  complex(DP), intent(in)  :: eigr(:,:)
  real(DP),    intent(out) :: dbec( :, :, :, : )
  integer, intent(in) :: idesc( :, : )
  !
  complex(DP), allocatable :: wrk2(:,:,:,:)
  real(DP),    allocatable :: dwrk_bgrp(:,:)
  !
  integer   :: ig, is, iv, ia, l, inl, i, j, ii, iw, iss, nr, ir, istart, nss
  integer   :: n1, n2, m1, m2, ibgrp_i, nrcx
  complex(DP) :: cfact
  !
  nrcx = MAXVAL(idesc(LAX_DESC_NRCX,:))
  !
  dbec = 0.0d0
  !
  allocate( wrk2( ngw, nkb, 3, 3 ) )
  allocate( dwrk_bgrp( nkb, nbspx_bgrp ) )
  !
  CALL dbeta_eigr( wrk2, eigr )
  !
  do j=1,3
     do i=1,3
        IF( ngw > 0 .AND. nkb > 0 ) THEN
           CALL dgemm( 'T', 'N', nkb, nbsp_bgrp, 2*ngw, 1.0d0, wrk2(1,1,i,j), 2*ngw, &
                             c_bgrp, 2*ngw, 0.0d0, dwrk_bgrp(1,1), nkb )
        END IF
        if( nproc_bgrp > 1 ) then
           call mp_sum( dwrk_bgrp, intra_bgrp_comm )
        end if
        do ia = 1, nat
           is = ityp(ia) 
           inl = indv_ijkb0(ia)
           do iss=1,nspin
              IF( idesc( LAX_DESC_ACTIVE_NODE, iss ) > 0 ) THEN
                 nr = idesc( LAX_DESC_NR, iss )
                 ir = idesc( LAX_DESC_IR, iss )
                 istart = iupdwn( iss )
                 nss    = nupdwn( iss )
                 do ii = 1, nr
                    ibgrp_i = ibgrp_g2l( ii + ir - 1 + istart - 1 )
                    IF( ibgrp_i > 0 ) THEN
                       do iw = 1, nh(is)
                          dbec( inl + iw, ii + (iss-1)*nrcx, i, j ) = dwrk_bgrp( inl + iw, ibgrp_i )
                       end do
                    END IF
                 end do
              END IF
           end do
        end do
     end do
  end do

  deallocate( wrk2 )
  deallocate( dwrk_bgrp )
  if( nbgrp > 1 ) then
     CALL mp_sum( dbec, inter_bgrp_comm )
  end if
  !
  return
end subroutine caldbec_bgrp_x
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
subroutine dennl_x( bec_bgrp, dbec, drhovan, denl, idesc )
  !-----------------------------------------------------------------------
  !
  !  compute the contribution of the non local part of the
  !  pseudopotentials to the derivative of E with respect to h
  !
  USE kinds,      ONLY : DP
  use uspp_param, only : nh
  use uspp,       only : nkb, dvan, deeq, indv_ijkb0
  use ions_base,  only : nat, ityp
  use cell_base,  only : h
  use io_global,  only : stdout
  use mp,         only : mp_sum
  use mp_global,  only : intra_bgrp_comm
  use electrons_base,     only : nbspx_bgrp, nbsp_bgrp, ispin_bgrp, f_bgrp, nspin, iupdwn, nupdwn, ibgrp_g2l
  use gvect, only : gstart

  implicit none

  include 'laxlib.fh'

  real(DP), intent(in)  :: dbec( :, :, :, : )
  real(DP), intent(in)  :: bec_bgrp( :, : )
  real(DP), intent(out) :: drhovan( :, :, :, :, : )
  real(DP), intent(out) :: denl( 3, 3 )
  INTEGER, intent(in) :: idesc( :, : )

  real(DP) :: dsum(3,3),dsums(2,3,3), detmp(3,3)
  integer   :: is, iv, jv, ijv, inl, jnl, ia, iss, i,j,k
  integer   :: istart, nss, ii, ir, nr, ibgrp, nrcx
  !
  nrcx = MAXVAL(idesc(LAX_DESC_NRCX,:))
  !
  denl=0.d0
  drhovan=0.0d0

!$omp parallel default(none) &
!$omp shared(nat,ityp,indv_ijkb0,nh,nbsp_bgrp,ispin_bgrp,f_bgrp,bec_bgrp,drhovan,dvan,nspin,denl) &
!$omp shared(idesc,iupdwn,nupdwn,ibgrp_g2l,nrcx,dbec) &
!$omp private(ia,is,iv,inl,jv,ijv,jnl,dsums,iss,i,dsum,ii,ir,k,j,nr,istart,nss,ibgrp)
!$omp do reduction(+:denl)
  do ia=1,nat
     is = ityp(ia) 
     do iv=1,nh(is)
        do jv=iv,nh(is)
           ijv = (jv-1)*jv/2 + iv
           inl = indv_ijkb0(ia) + iv
           jnl = indv_ijkb0(ia) + jv
           dsums=0.d0
           do iss=1,nspin
              IF( ( idesc( LAX_DESC_ACTIVE_NODE, iss ) > 0 ) .AND. &
                  ( idesc( LAX_DESC_MYR, iss ) == idesc( LAX_DESC_MYC, iss ) ) ) THEN
                 nr = idesc( LAX_DESC_NR, iss )
                 ir = idesc( LAX_DESC_IR, iss )
                 istart = iupdwn( iss )
                 nss    = nupdwn( iss )
                 do i=1,nr
                    ii = i+istart-1+ir-1
                    ibgrp = ibgrp_g2l( ii )
                    IF( ibgrp > 0 ) THEN
                       do k=1,3
                          do j=1,3
                             dsums(iss,k,j) = dsums(iss,k,j) + f_bgrp(ibgrp) *       &
 &                          ( dbec(inl,i+(iss-1)*nrcx,k,j)*bec_bgrp(jnl,ibgrp)          &
 &                          + bec_bgrp(inl,ibgrp)*dbec(jnl,i+(iss-1)*nrcx,k,j) )
                          enddo
                       enddo
                    END IF
                 end do
                 dsum=0.d0
                 do k=1,3
                    do j=1,3
                       drhovan(ijv,ia,iss,j,k)=dsums(iss,j,k)
                       dsum(j,k)=dsum(j,k)+dsums(iss,j,k)
                    enddo
                 enddo
                 if(iv.ne.jv) dsum=2.d0*dsum
                 denl = denl + dsum * dvan(jv,iv,is)
              END IF
           end do
        end do
     end do
  end do
!$omp end do
!$omp end parallel

  CALL mp_sum( denl,    intra_bgrp_comm )
  CALL mp_sum( drhovan, intra_bgrp_comm )

!  WRITE(6,*) 'DEBUG enl (CP) = '
!  detmp = denl
!  detmp = MATMUL( detmp(:,:), TRANSPOSE( h ) )
!  WRITE( stdout,5555) ((detmp(i,j),j=1,3),i=1,3)
!5555  format(1x,f12.5,1x,f12.5,1x,f12.5/                                &
!     &       1x,f12.5,1x,f12.5,1x,f12.5/                                &
!     &       1x,f12.5,1x,f12.5,1x,f12.5//)
!
  !
  return
end subroutine dennl_x
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
subroutine nlfq_bgrp_x( c_bgrp, eigr, bec_bgrp, becdr_bgrp, fion )
  !-----------------------------------------------------------------------
  !
  !     contribution to fion due to nonlocal part
  !
  USE kinds,          ONLY : DP
  use uspp,           only : nkb, dvan, deeq, indv_ijkb0
  use uspp_param,     only : nhm, nh
  use ions_base,      only : nax, nat, ityp
  use electrons_base, only : nbsp_bgrp, f_bgrp, nbspx_bgrp, ispin_bgrp
  use gvecw,          only : ngw
  use constants,      only : pi, fpi
  use mp_global,      only : intra_bgrp_comm, nbgrp, inter_bgrp_comm, world_comm
  use mp_global,      only : me_bgrp, nproc_bgrp
  use mp,             only : mp_sum
  use cp_interfaces,  only : nlsm2_bgrp
  !
  implicit none
  !
  COMPLEX(DP), INTENT(IN) :: c_bgrp( :, : )
#if defined (__CUDA)
  ATTRIBUTES( DEVICE ) :: c_bgrp
#endif
  COMPLEX(DP), INTENT(IN)  ::  eigr( :, : )
  REAL(DP),    INTENT(IN)  ::  bec_bgrp( :, : )
  REAL(DP),    INTENT(OUT)  ::  becdr_bgrp( :, :, : )
  REAL(DP),    INTENT(OUT) ::  fion( :, : )
  !
  integer  :: k, is, ia, inl, jnl, iv, jv, i
  real(DP) :: temp
  real(DP) :: sum_tmpdr
  !
  real(DP), allocatable :: tmpbec(:,:), tmpdr(:,:) 
  real(DP), allocatable :: fion_loc(:,:)
#if defined(_OPENMP) 
  INTEGER :: mytid, ntids, omp_get_thread_num, omp_get_num_threads
#endif  
  !
  call start_clock( 'nlfq' )
  !
  !     nlsm2 fills becdr
  !
  call nlsm2_bgrp( ngw, nkb, eigr, c_bgrp, becdr_bgrp, nbspx_bgrp, nbsp_bgrp )
  !
  allocate ( fion_loc( 3, nat ) )
  !
  fion_loc = 0.0d0
  !
!$omp parallel default(none), &
!$omp shared(becdr_bgrp,bec_bgrp,fion_loc,f_bgrp,deeq,dvan,nbsp_bgrp,indv_ijkb0,nh, &
!$omp        nat,nhm,nbspx_bgrp,ispin_bgrp,nproc_bgrp,me_bgrp,ityp), &
!$omp private(tmpbec,tmpdr,is,ia,iv,jv,k,inl,jnl,temp,i,mytid,ntids,sum_tmpdr)

#if defined(_OPENMP)
  mytid = omp_get_thread_num()  ! take the thread ID
  ntids = omp_get_num_threads() ! take the number of threads
#endif

  allocate ( tmpbec( nbspx_bgrp, nhm ), tmpdr( nbspx_bgrp, nhm ) )

  DO k = 1, 3
     DO ia = 1, nat
        is = ityp(ia)

        ! better if we distribute to MPI tasks too!
        !
        IF( MOD( ia + (k-1)*nat, nproc_bgrp ) /= me_bgrp ) CYCLE

#if defined(_OPENMP)
        ! distribute atoms round robin to threads
        !
        IF( MOD( ( ia + (k-1)*nat ) / nproc_bgrp, ntids ) /= mytid ) CYCLE
#endif  
        tmpbec = 0.d0
        do jv=1,nh(is)
           jnl = indv_ijkb0(ia) + jv
           do iv=1,nh(is)
              do i = 1, nbsp_bgrp
                 temp = dvan(iv,jv,is) + deeq(jv,iv,ia,ispin_bgrp( i ) )
                 tmpbec(i,iv) = tmpbec(i,iv) + temp * bec_bgrp(jnl,i)
              end do
           end do
        end do

        do iv = 1, nh(is)
           inl = indv_ijkb0(ia) + iv
           do i = 1, nbsp_bgrp
              tmpdr(i,iv) = f_bgrp( i ) * becdr_bgrp( inl, i, k )
           end do
        end do

        sum_tmpdr = 0.0d0
        do iv = 1, nh(is)
           do i = 1, nbsp_bgrp
              sum_tmpdr = sum_tmpdr + tmpdr(i,iv)*tmpbec(i,iv)
           end do
        end do

        fion_loc(k,ia) = fion_loc(k,ia)-2.d0*sum_tmpdr

     END DO
  END DO
  deallocate ( tmpbec, tmpdr )

!$omp end parallel
  !
  CALL mp_sum( fion_loc, intra_bgrp_comm )
  IF( nbgrp > 1 ) THEN
     CALL mp_sum( fion_loc, inter_bgrp_comm )
  END IF
  !
  fion = fion + fion_loc
  !
  !     end of x/y/z loop
  !
  deallocate ( fion_loc )
  !
  call stop_clock( 'nlfq' )
  !
  return
end subroutine nlfq_bgrp_x
