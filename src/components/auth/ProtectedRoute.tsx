import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { hasPermission } from '@/lib/roles';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: string;
  requiredPermission?: readonly string[];
}

const ProtectedRoute = ({ children, requiredRole, requiredPermission }: ProtectedRouteProps) => {
  const { user, loading, hasRole, userRoles } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading) {
      if (!user) {
        navigate('/login');
      } else if (requiredRole && !hasRole(requiredRole)) {
        navigate('/dashboard');
      } else if (requiredPermission && !hasPermission(userRoles, requiredPermission)) {
        navigate('/dashboard');
      }
    }
  }, [user, loading, requiredRole, requiredPermission, navigate, hasRole, userRoles]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (!user) return null;
  if (requiredRole && !hasRole(requiredRole)) return null;
  if (requiredPermission && !hasPermission(userRoles, requiredPermission)) return null;

  return <>{children}</>;
};

export default ProtectedRoute;
