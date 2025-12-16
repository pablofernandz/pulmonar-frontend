import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/home/role_select_page.dart';
import '../core/auth/token_storage.dart';

import '../features/coordinator/ui/coordinator_shell.dart';
import '../features/coordinator/ui/coordinator_home.dart';
import '../features/users/ui/users_search_page.dart';
import '../features/users/ui/user_create_page.dart';
import '../features/users/ui/user_detail_page.dart';
import '../features/groups/ui/groups_list_page.dart';
import '../features/groups/ui/group_create_page.dart';
import '../features/groups/ui/group_detail_page.dart';
import 'package:tfg_app2/features/profile/ui/my_profile_page.dart';

import 'package:tfg_app2/features/surveys/ui/surveys_home_page.dart';
import 'package:tfg_app2/features/surveys/ui/surveys_search_page.dart';
import 'package:tfg_app2/features/surveys/ui/surveys_create_page.dart';

import '../features/revisor/ui/revisor_home_page.dart';
import '../features/revisor/ui/revisor_patients_page.dart';
import '../features/revisor/ui/survey_run_page.dart';
import '../features/revisor/ui/patient_detail_page.dart';
import '../features/revisor/ui/revisor_evaluation_start_page.dart';
import '../features/revisor/ui/revisor_patients_eval_page.dart';

import '../features/revisor/ui/evaluation_viewer_page.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.go('/patient/profile');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home Paciente')),
    );
  }
}

String? _routeForRole(String? role) {
  if (role == null || role.trim().isEmpty) return null;
  switch (role.trim().toLowerCase()) {
    case 'patient':
      return '/patient';
    case 'revisor':
    case 'tutor':
      return '/revisor';
    case 'coordinator':
      return '/coordinator';
    default:
      return null;
  }
}

GoRouter buildRouter() => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/role', builder: (_, __) => const RoleSelectPage()),

        GoRoute(
          path: '/patient',
          builder: (_, __) => const PatientHome(),
          routes: [
            GoRoute(
              path: 'profile',
              builder: (_, __) => const MyProfilePage(
                showPatientEvaluations: true,
                showLogoutInAppBar: true, 
              ),
            ),
            GoRoute(
              path: 'evaluations/:id',
              builder: (_, state) {
                final id =
                    int.tryParse(state.pathParameters['id'] ?? '');
                if (id == null) {
                  return const Scaffold(
                    body: Center(
                        child: Text('ID de evaluación inválido')),
                  );
                }
                return EvaluationViewerPage(evaluationId: id);
              },
            ),
          ],
        ),

        GoRoute(
          path: '/revisor',
          builder: (_, __) => const RevisorHomePage(),
          routes: [
            GoRoute(
              path: 'profile',
              builder: (_, __) => const MyProfilePage(),
            ),
            GoRoute(
              path: 'pacientes',
              builder: (_, __) => const RevisorPatientsPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) {
                    final id =
                        int.tryParse(state.pathParameters['id'] ?? '');
                    if (id == null) {
                      return const Scaffold(
                        body: Center(
                          child: Text('ID de paciente inválido'),
                        ),
                      );
                    }
                    return RevisorPatientDetailPage(userId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'evaluar',
              builder: (_, __) => const RevisorPatientsEvalPage(),
              routes: [
                GoRoute(
                  path: ':patientId',
                  name: 'revisor-evaluar',
                  builder: (_, state) {
                    final pid = int.tryParse(
                        state.pathParameters['patientId'] ?? '');
                    if (pid == null) {
                      return const Scaffold(
                        body: Center(
                          child: Text('ID de paciente inválido'),
                        ),
                      );
                    }
                    return RevisorEvaluationStartPage(patientId: pid);
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'evaluations/:id',
              builder: (_, state) {
                final id =
                    int.tryParse(state.pathParameters['id'] ?? '');
                if (id == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('ID de evaluación inválido'),
                    ),
                  );
                }
                return EvaluationViewerPage(evaluationId: id);
              },
            ),
            GoRoute(
              path: 'start/:patientId',
              builder: (_, state) {
                final pid = int.tryParse(
                    state.pathParameters['patientId'] ?? '');
                if (pid == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('ID de paciente inválido'),
                    ),
                  );
                }
                return RevisorEvaluationStartPage(patientId: pid);
              },
            ),
            GoRoute(
              path: 'run/:patientId/:surveyId',
              name: 'revisor-run',
              builder: (_, state) {
                final patientId = int.tryParse(
                    state.pathParameters['patientId'] ?? '');
                final surveyId = int.tryParse(
                    state.pathParameters['surveyId'] ?? '');
                if (patientId == null || surveyId == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Parámetros inválidos para el runner'),
                    ),
                  );
                }
                return SurveyRunPage(
                  patientId: patientId,
                  surveyId: surveyId,
                );
              },
            ),
          ],
        ),

        GoRoute(
          path: '/coordinator/profile',
          builder: (_, __) => const MyProfilePage(),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              CoordinatorShell(child: child),
          routes: [
            GoRoute(
              path: '/coordinator',
              builder: (_, __) => const CoordinatorHomePage(),
              routes: [
                GoRoute(
                  path: 'stats',
                  builder: (_, __) => const Scaffold(
                    body: Center(
                      child: Text('Estadísticas (pendiente)'),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'forms',
                  builder: (_, __) => const SurveysHomePage(),
                  routes: [
                    GoRoute(
                      path: 'search',
                      builder: (_, __) =>
                          const SurveysSearchPage(),
                    ),
                    GoRoute(
                      path: 'new',
                      builder: (_, __) =>
                          const SurveysCreatePage(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'users',
                  builder: (_, __) => const UsersSearchPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (_, __) =>
                          const UserCreatePage(),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (_, state) {
                        final id = int.tryParse(
                            state.pathParameters['id'] ?? '');
                        return (id == null)
                            ? const Scaffold(
                                body: Center(
                                  child: Text('ID de usuario inválido'),
                                ),
                              )
                            : UserDetailPage(userId: id);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'groups',
                  builder: (_, __) => const GroupsListPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (_, __) =>
                          const GroupCreatePage(),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (_, st) {
                        final id = int.tryParse(
                            st.pathParameters['id'] ?? '');
                        if (id == null) {
                          return const Scaffold(
                            body: Center(
                              child: Text('Grupo inválido'),
                            ),
                          );
                        }
                        return GroupDetailPage(id: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      redirect: (ctx, state) async {
        final loc = state.matchedLocation;
        final token =
            (await TokenStorage.instance.getToken())?.trim();
        final roleRaw =
            (await TokenStorage.instance.getRole())?.trim();
        final roleRoute = _routeForRole(roleRaw);

        final atLogin = loc == '/login';
        final atRole = loc == '/role';

        if (token == null || token.isEmpty) {
          return atLogin ? null : '/login';
        }

        if (roleRoute != null) {
          if (loc == roleRoute || loc.startsWith('$roleRoute/')) {
            return null;
          }
          return roleRoute;
        }

        if (!atRole) return '/role';
        return null;
      },
      errorBuilder: (ctx, st) =>
          Scaffold(body: Center(child: Text('404: ${st.error}'))),
    );
