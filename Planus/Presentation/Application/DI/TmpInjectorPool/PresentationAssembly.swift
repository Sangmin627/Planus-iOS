//
//  PresentationAssembly.swift
//  Planus
//
//  Created by Sangmin Lee on 3/9/24.
//

import Foundation
import Swinject

class PresentationAssembly: Assembly {
    func assemble(container: Swinject.Container) {
        assembleMyPageMain(container: container)
        assembleMyPageReadableViewModel(container: container)
        assembleMyPageEnquire(container: container)
        assembleMyPageEdit(container: container)
        
        assembleHomeCalendar(container: container)
        assembleDailyCalendar(container: container)
        assembleTodoDetail(container: container)
        
        assembleSignIn(container: container)
        assembleRedirectionalWeb(container: container)
        
        assembleSearchHome(container: container)
        assembleSearchResult(container: container)
        
        assembleGroupCreate(container: container)
        assembleGroupCreateLoading(container: container)
        
        assembleGroupIntroduce(container: container)
        
        assembleNotification(container: container)
    }
    
}

import Swinject

extension PresentationAssembly {
    func assembleMyPageMain(container: Container) {
        container.register(MyPageMainViewModel.self) { (r, injectable: MyPageMainViewModel.Injectable) in
            return MyPageMainViewModel(
                useCases: .init(
                    updateProfileUseCase: r.resolve(UpdateProfileUseCase.self)!,
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    removeTokenUseCase: r.resolve(RemoveTokenUseCase.self)!,
                    removeProfileUseCase: r.resolve(RemoveProfileUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!,
                    getSignedInSNSTypeUseCase: r.resolve(GetSignedInSNSTypeUseCase.self)!,
                    convertToSha256UseCase: r.resolve(ConvertToSha256UseCase.self)!,
                    revokeAppleTokenUseCase: r.resolve(RevokeAppleTokenUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(MyPageMainViewController.self) { (r, injectable: MyPageMainViewModel.Injectable) in
            return MyPageMainViewController(viewModel: r.resolve(MyPageMainViewModel.self, argument: injectable)!)
        }
    }
    
    func assembleMyPageReadableViewModel(container: Container) {
        container.register(MyPageReadableViewModel.self) { (r, injectable: MyPageReadableViewModel.Injectable) in
            return MyPageReadableViewModel(
                useCases: .init(),
                injectable: injectable
            )
        }
        
        container.register(MyPageReadableViewController.self) { (r, injectable: MyPageReadableViewModel.Injectable) in
            return MyPageReadableViewController(viewModel: r.resolve(MyPageReadableViewModel.self, argument: injectable)!)
        }
    }

    
    func assembleMyPageEnquire(container: Container) {
        container.register(MyPageEnquireViewModel.self) { r in
            return MyPageEnquireViewModel()
        }
        
        container.register(MyPageEnquireViewController.self) { r in
            return MyPageEnquireViewController(viewModel: r.resolve(MyPageEnquireViewModel.self)!)
        }
    }
    
    func assembleMyPageEdit(container: Container) {
        container.register(MyPageEditViewModel.self) { (r, injectable: MyPageEditViewModel.Injectable) in
            return MyPageEditViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    readProfileUseCase: r.resolve(ReadProfileUseCase.self)!,
                    updateProfileUseCase: r.resolve(UpdateProfileUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(MyPageEditViewController.self) { (r, injectable: MyPageEditViewModel.Injectable) in
            return MyPageEditViewController(viewModel: r.resolve(MyPageEditViewModel.self, argument: injectable)!)
        }
    }
    
}


extension PresentationAssembly {
    func assembleHomeCalendar(container: Container) {
        container.register(HomeCalendarViewModel.self) { (r, injectable: HomeCalendarViewModel.Injectable) in
            return HomeCalendarViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    createTodoUseCase: r.resolve(CreateTodoUseCase.self)!,
                    readTodoListUseCase: r.resolve(ReadTodoListUseCase.self)!,
                    updateTodoUseCase: r.resolve(UpdateTodoUseCase.self)!,
                    deleteTodoUseCase: r.resolve(DeleteTodoUseCase.self)!,
                    todoCompleteUseCase: r.resolve(TodoCompleteUseCase.self)!,
                    createCategoryUseCase: r.resolve(CreateCategoryUseCase.self)!,
                    readCategoryListUseCase: r.resolve(ReadCategoryListUseCase.self)!,
                    updateCategoryUseCase: r.resolve(UpdateCategoryUseCase.self)!,
                    deleteCategoryUseCase: r.resolve(DeleteCategoryUseCase.self)!,
                    fetchGroupCategoryListUseCase: r.resolve(FetchAllGroupCategoryListUseCase.self)!,
                    fetchMyGroupNameListUseCase: r.resolve(FetchMyGroupNameListUseCase.self)!,
                    groupCreateUseCase: r.resolve(GroupCreateUseCase.self)!,
                    withdrawGroupUseCase: r.resolve(WithdrawGroupUseCase.self)!,
                    deleteGroupUseCase: r.resolve(DeleteGroupUseCase.self)!,
                    createMonthlyCalendarUseCase: r.resolve(CreateMonthlyCalendarUseCase.self)!,
                    dateFormatYYYYMMUseCase: r.resolve(DateFormatYYYYMMUseCase.self)!,
                    readProfileUseCase: r.resolve(ReadProfileUseCase.self)!,
                    updateProfileUseCase: r.resolve(UpdateProfileUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(HomeCalendarViewController.self) { (r, injectable: HomeCalendarViewModel.Injectable) in
            return HomeCalendarViewController(viewModel: r.resolve(HomeCalendarViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    func assembleDailyCalendar(container: Container) {
        container.register(DailyCalendarViewModel.self) { (r, injectable: DailyCalendarViewModel.Injectable) in
            return DailyCalendarViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    createTodoUseCase: r.resolve(CreateTodoUseCase.self)!,
                    updateTodoUseCase: r.resolve(UpdateTodoUseCase.self)!,
                    deleteTodoUseCase: r.resolve(DeleteTodoUseCase.self)!,
                    todoCompleteUseCase: r.resolve(TodoCompleteUseCase.self)!,
                    createCategoryUseCase: r.resolve(CreateCategoryUseCase.self)!,
                    updateCategoryUseCase: r.resolve(UpdateCategoryUseCase.self)!,
                    deleteCategoryUseCase: r.resolve(DeleteCategoryUseCase.self)!,
                    readCategoryUseCase: r.resolve(ReadCategoryListUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(DailyCalendarViewController.self) { (r, injectable: DailyCalendarViewModel.Injectable) in
            return DailyCalendarViewController(viewModel: r.resolve(DailyCalendarViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    enum TodoDetailPageType: String {
        case memberTodo = "MEMBER_TODO_DETAIL"
        case socialTodo = "SOCIAL_TODO_DETAIL"
    }
    
    func assembleTodoDetail(container: Container) {
        container.register(
            MemberTodoDetailViewModel.self
        ) { (r, injectable: MemberTodoDetailViewModel.Injectable) in
            return MemberTodoDetailViewModel(
                getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                createTodoUseCase: r.resolve(CreateTodoUseCase.self)!,
                updateTodoUseCase: r.resolve(UpdateTodoUseCase.self)!,
                deleteTodoUseCase: r.resolve(DeleteTodoUseCase.self)!,
                createCategoryUseCase: r.resolve(CreateCategoryUseCase.self)!,
                updateCategoryUseCase: r.resolve(UpdateCategoryUseCase.self)!,
                deleteCategoryUseCase: r.resolve(DeleteCategoryUseCase.self)!,
                readCategoryUseCase: r.resolve(ReadCategoryListUseCase.self)!,
                injectable: injectable
            )
        }
        
        container.register(
            TodoDetailViewController.self,
            name: TodoDetailPageType.memberTodo.rawValue
        ) { (r, injectable: MemberTodoDetailViewModel.Injectable) in
            let vm = r.resolve(MemberTodoDetailViewModel.self, argument: injectable)!
            return TodoDetailViewController(viewModel: vm)
        }
    }
}


extension PresentationAssembly {
    func assembleSignIn(container: Container) {
        container.register(SignInViewModel.self) { (r, injectable: SignInViewModel.Injectable) in
            return SignInViewModel(
                useCases: SignInViewModel.UseCases(
                    kakaoSignInUseCase: r.resolve(KakaoSignInUseCase.self)!,
                    googleSignInUseCase: r.resolve(GoogleSignInUseCase.self)!,
                    appleSignInUseCase: r.resolve(AppleSignInUseCase.self)!,
                    convertToSha256UseCase: r.resolve(ConvertToSha256UseCase.self)!,
                    setSignedInSNSTypeUseCase: r.resolve(SetSignedInSNSTypeUseCase.self)!,
                    revokeAppleTokenUseCase: r.resolve(RevokeAppleTokenUseCase.self)!,
                    setTokenUseCase: r.resolve(SetTokenUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(SignInViewController.self) { (r, injectable: SignInViewModel.Injectable) in
            return SignInViewController(viewModel: r.resolve(SignInViewModel.self, argument: injectable)!)
        }
    }
    
    func assembleRedirectionalWeb(container: Container) {
        container.register(RedirectionalWebViewModel.self) { (r, injectable: RedirectionalWebViewModel.Injectable) in
            return RedirectionalWebViewModel(useCases: .init(), injectable: injectable)
        }
        
        container.register(RedirectionalWebViewController.self) { (r, injectable: RedirectionalWebViewModel.Injectable) in
            return RedirectionalWebViewController(viewModel: r.resolve(RedirectionalWebViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    func assembleSearchHome(container: Container) {
        container.register(SearchHomeViewModel.self) { (r, injectable: SearchHomeViewModel.Injectable) in
            return SearchHomeViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    fetchSearchHomeUseCase: r.resolve(FetchSearchHomeUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(SearchHomeViewController.self) { (r, injectable: SearchHomeViewModel.Injectable) in
            return SearchHomeViewController(viewModel: r.resolve(SearchHomeViewModel.self, argument: injectable)!)
        }
    }
    
    func assembleSearchResult(container: Container) {
        container.register(SearchResultViewModel.self) { (r, injectable: SearchResultViewModel.Injectable) in
            return SearchResultViewModel(
                useCases: .init(
                    recentQueryRepository: r.resolve(RecentQueryRepository.self)!,
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    fetchSearchResultUseCase: r.resolve(FetchSearchResultUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(SearchHomeViewController.self) { (r, injectable: SearchHomeViewModel.Injectable) in
            return SearchHomeViewController(viewModel: r.resolve(SearchHomeViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    func assembleGroupCreate(container: Container) {
        container.register(GroupCreateViewModel.self) { (r, injectable: GroupCreateViewModel.Injectable) in
            return GroupCreateViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    groupCreateUseCase: r.resolve(GroupCreateUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(GroupCreateViewController.self) { (r, injectable: GroupCreateViewModel.Injectable) in
            return GroupCreateViewController(viewModel: r.resolve(GroupCreateViewModel.self, argument: injectable)!)
        }
    }
    
    func assembleGroupCreateLoading(container: Container) {
        container.register(GroupCreateLoadViewModel.self) { (r, injectable: GroupCreateLoadViewModel.Injectable) in
            return GroupCreateLoadViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    groupCreateUseCase: r.resolve(GroupCreateUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(GroupCreateLoadViewController.self) { (r, injectable: GroupCreateLoadViewModel.Injectable) in
            return GroupCreateLoadViewController(viewModel: r.resolve(GroupCreateLoadViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    func assembleGroupIntroduce(container: Container) {
        container.register(GroupIntroduceViewModel.self) { (r, injectable: GroupIntroduceViewModel.Injectable) in
            return GroupIntroduceViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    setTokenUseCase: r.resolve(SetTokenUseCase.self)!,
                    fetchUnJoinedGroupUseCase: r.resolve(FetchUnJoinedGroupUseCase.self)!,
                    fetchMemberListUseCase: r.resolve(FetchMemberListUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!,
                    applyGroupJoinUseCase: r.resolve(ApplyGroupJoinUseCase.self)!,
                    generateGroupLinkUseCase: r.resolve(GenerateGroupLinkUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(GroupIntroduceViewController.self) { (r, injectable: GroupIntroduceViewModel.Injectable) in
            return GroupIntroduceViewController(viewModel: r.resolve(GroupIntroduceViewModel.self, argument: injectable)!)
        }
    }
}

extension PresentationAssembly {
    func assembleNotification(container: Container) {
        container.register(NotificationViewModel.self) { (r, injectable: NotificationViewModel.Injectable) in
            return NotificationViewModel(
                useCases: .init(
                    getTokenUseCase: r.resolve(GetTokenUseCase.self)!,
                    refreshTokenUseCase: r.resolve(RefreshTokenUseCase.self)!,
                    setTokenUseCase: r.resolve(SetTokenUseCase.self)!,
                    fetchJoinApplyListUseCase: r.resolve(FetchJoinApplyListUseCase.self)!,
                    fetchImageUseCase: r.resolve(FetchImageUseCase.self)!,
                    acceptGroupJoinUseCase: r.resolve(AcceptGroupJoinUseCase.self)!,
                    denyGroupJoinUseCase: r.resolve(DenyGroupJoinUseCase.self)!
                ),
                injectable: injectable
            )
        }
        
        container.register(NotificationViewController.self) { (r, injectable: NotificationViewModel.Injectable) in
            return NotificationViewController(viewModel: r.resolve(NotificationViewModel.self, argument: injectable)!)
        }
    }
}
